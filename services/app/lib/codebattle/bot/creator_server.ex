defmodule Codebattle.Bot.CreatorServer do
  require Logger

  use GenServer

  alias Codebattle.Repo
  alias Codebattle.Bot.PlaybookAsyncRunner

  @timeout Application.get_env(:codebattle, Codebattle.Bot)[:timeout]

  def start_link() do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(state) do
    Process.send_after(self(), :create_bot_if_needed, @timeout)
    {:ok, %{}}
  end

  def handle_info(:create_bot_if_needed, state) do
    levels = ["elementary", "easy", "medium", "hard"]

    for level <- levels do
      # create fsm for every level, if no waiting opponent games
      case Codebattle.Bot.GameCreator.call(level) do
        {:ok, game_id, bot} ->
          # create bots gen_server for every game
          {:ok, pid} = PlaybookAsyncRunner.create_server(%{game_id: game_id, bot: bot})

        {:error, reason} ->
          nil
      end
    end

    Process.send_after(self(), :create_bot_if_needed, 3_000)
    {:noreply, %{}}
  end

  def handle_info(_, state) do
    {:noreply, state}
  end
end
