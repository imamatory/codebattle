defmodule Codebattle.Bot.GameCreator do
  alias Codebattle.GameProcess.Play
  alias Codebattle.Repo
  alias Codebattle.Bot.Playbook

  import Ecto.Query, warn: false

  def call(level) do
    games = Play.active_games(%{is_bot: true, state: :waiting_opponent, level: level})

    if Enum.count(games) < 1 do
      bot = Codebattle.Bot.Builder.build()

      case Play.create_bot_game(bot, %{"level" => level, "type" => "public"}) do
        {:ok, game_id} ->
          {:ok, game_id, bot}

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:error, :game_limit}
    end
  end
end
