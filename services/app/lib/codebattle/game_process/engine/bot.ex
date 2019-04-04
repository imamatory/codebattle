defmodule Codebattle.GameProcess.Engine.Bot do
  import Codebattle.GameProcess.Engine.Base

  alias Codebattle.GameProcess.{
    Play,
    Server,
    GlobalSupervisor,
    Fsm,
    Player,
    FsmHelpers,
    Elo,
    ActiveGames,
    Notifier
  }

  alias Codebattle.{Repo, User, Game, UserGame}
  alias Codebattle.Bot.{RecorderServer, Playbook}
  alias Codebattle.User.Achievements

  import Ecto.Query, warn: false

  def create_game(bot, %{"level" => level, "type" => type}) do
    bot_player = Player.build(bot, %{creator: true})

    game = Repo.insert!(%Game{state: "waiting_opponent", level: level, type: type})

    fsm =
      Fsm.new()
      |> Fsm.create(%{
        player: bot_player,
        level: level,
        game_id: game.id,
        bots: true,
        type: type,
        starts_at: TimeHelper.utc_now()
      })

    ActiveGames.create_game(game.id, fsm)
    {:ok, _} = GlobalSupervisor.start_game(game.id, fsm)

    {:ok, fsm}
  end

  def join_game(game_id, second_player) do
    game = Play.get_game(game_id)
    fsm = Play.get_fsm(game_id)
    first_player = FsmHelpers.get_first_player(fsm)
    level = FsmHelpers.get_level(fsm)

    case get_playbook(level) do
      {:ok, playbook} ->
        update_game!(game_id, %{state: "playing", task_id: playbook.task.id})

        case Server.call_transition(game_id, :join, %{
               player: second_player,
               task: playbook.task,
               joins_at: TimeHelper.utc_now()
             }) do
          {:ok, fsm} ->
            ActiveGames.add_participant(fsm)

            {:ok, _} = Codebattle.Bot.Supervisor.start_record_server(game_id, second_player, fsm)

            Codebattle.Bot.PlaybookAsyncRunner.call(%{
              game_id: game_id,
              task_id: playbook.task.id
            })

            {:ok, fsm}

          {:error, _reason} ->
            {:error, _reason}
        end

      {:error, _reason} ->
        {:error, _reason}
    end
  end

  def update_text(game_id, player, editor_text) do
    update_fsm_text(game_id, player, editor_text)
  end

  def update_lang(game_id, player, editor_lang) do
    update_fsm_lang(game_id, player, editor_lang)
  end

  def handle_won_game(game_id, winner, fsm) do
    loser = FsmHelpers.get_opponent(fsm, winner.id)

    store_game_result_async!(fsm, {winner, "won"}, {loser, "lost"})

    unless winner.is_bot do
      :ok = RecorderServer.store(game_id, winner.id)
    end

    ActiveGames.terminate_game(game_id)
  end

  def handle_give_up(game_id, loser, fsm) do
    winner = FsmHelpers.get_opponent(fsm, loser.id)

    store_game_result_async!(fsm, {winner, "won"}, {loser, "gave_up"})
    ActiveGames.terminate_game(game_id)
  end

  def get_playbook(level) do
    query =
      from(
        playbook in Playbook,
        join: task in "tasks",
        on: task.id == playbook.task_id,
        order_by: fragment("RANDOM()"),
        preload: [:task],
        where: task.level == ^level,
        limit: 1
      )

    playbook = Repo.one(query)

    if playbook do
      {:ok, playbook}
    else
      {:error, :playbook_not_found}
    end
  end
end
