defmodule Codebattle.Bot.RecorderServer do
  @moduledoc "Gen server for calculating bot diffs and store it to database after user_id won the game"

  @time_limit Application.get_env(:codebattle, Codebattle.Bot.RecorderServer)[:limit]

  require Logger

  use GenServer

  alias Codebattle.Repo
  alias Codebattle.Bot.Playbook

  import Codebattle.GameProcess.FsmHelpers

  # API
  def start_link({game_id, user_id, fsm}) do
    GenServer.start_link(
      __MODULE__,
      {game_id, user_id, fsm},
      name: server_name(game_id, user_id)
    )
  end

  def update_text(game_id, user_id, text) do
    try do
      GenServer.cast(server_name(game_id, user_id), {:update_text, text})
    rescue
      e in FunctionClauseError -> e
    end
  end

  def update_lang(game_id, user_id, lang) do
    try do
      GenServer.cast(server_name(game_id, user_id), {:update_lang, lang})
    rescue
      e in FunctionClauseError -> e
    end
  end

  def store(game_id, user_id) do
    try do
      GenServer.cast(server_name(game_id, user_id), {:store})
    rescue
      e in FunctionClauseError ->
        Logger.error(inspect(e))
    end
  end

  def recorder_pid(game_id, user_id) do
    :gproc.where(recorder_key(game_id, user_id))
  end

  # SERVER
  def init({game_id, user_id, fsm}) do
    {:ok,
     %{
       game_id: game_id,
       task_id: get_task(fsm).id,
       user_id: user_id,
       delta: TextDelta.new([]),
       lang: "js",
       time: nil,
       # Array of diffs to db playbook
       diff: []
     }}
  end

  def handle_cast({:update_text, text}, state) do

    time = state.time || NaiveDateTime.utc_now()
    new_time = NaiveDateTime.utc_now()
    new_delta = TextDelta.new() |> TextDelta.insert(text)

    diff = %{
      delta: TextDelta.diff!(state.delta, new_delta).ops,
      time: time_diff(new_time, time)
    }

    new_state = %{state | delta: new_delta, diff: [diff | state.diff], time: new_time}

    {:noreply, new_state}
  end

  def handle_cast({:update_lang, lang}, state) do
    time = state.time || NaiveDateTime.utc_now()
    new_time = NaiveDateTime.utc_now()

    diff = %{
      lang: lang,
      time: time_diff(new_time, time)
    }

    new_state = %{state | lang: lang, diff: [diff | state.diff], time: new_time}

    {:noreply, new_state}
  end

  def handle_cast({:store}, state) do

    %Playbook{
      data: %{
        playbook: Enum.reverse(state.diff),
        meta: %{
          total_time: calc_total_time(state.diff),
          total_steps: Enum.count(state.diff)
        }
      },
      lang: to_string(state.lang),
      task_id: state.task_id,
      user_id: state.user_id,
      game_id: state.game_id |> to_string |> Integer.parse() |> elem(0)
    }
    |> Repo.insert()

    {:stop, :normal, state}
  end

  # HELPERS
  def server_name(game_id, user_id) do
    {:via, :gproc, recorder_key(game_id, user_id)}
  end

  def recorder_key(game_id, user_id) do
    {:n, :l, {:bot_recorder, "#{game_id}_#{user_id}"}}
  end

  defp calc_total_time(state) do
    Enum.reduce(state, 0, fn x, acc -> x.time + acc end)
  end

  defp time_diff(new_time, time) do
    step_time = NaiveDateTime.diff(new_time, time, :millisecond)
    cond do
      step_time > @time_limit -> 3000
      true -> step_time
    end
  end
end
