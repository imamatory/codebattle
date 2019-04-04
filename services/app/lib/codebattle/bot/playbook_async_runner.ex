defmodule Codebattle.Bot.PlaybookAsyncRunner do
  @moduledoc """
  Process for playing playbooks of tasks
  """
  use GenServer

  require Logger

  alias Codebattle.Bot.Playbook
  alias Codebattle.GameProcess.Play

  # API
  def start(%{game_id: game_id, bot: bot}) do
    try do
      GenServer.start(__MODULE__, %{game_id: game_id, bot: bot}, name: server_name(game_id))
    rescue
      e in FunctionClauseError ->
        e
        Logger.error(inspect(e))
    end
  end

  def call(params) do
    GenServer.cast(server_name(params.game_id), {:run, params})
  end

  # SERVER

  def init(params) do
    Logger.info("Start bot palyer server for game_id: #{inspect(params.game_id)}")
    {:ok, params}
  end

  def handle_cast({:run, params}, state) do
    port = CodebattleWeb.Endpoint.struct_url().port

    # TODO: FIXME move to config
    {schema, new_port} =
      case port do
        # dev
        4000 ->
          {"wss", port}

        # test
        4001 ->
          {"ws", port}

        # prod
        _ ->
          {"ws", 8080}
      end

    socket_opts = [
      url:
        "#{schema}://localhost:#{new_port}/ws/websocket?vsn=2.0.0&token=#{bot_token(state.bot.id)}"
    ]

    {:ok, socket} = PhoenixClient.Socket.start_link(socket_opts)

    game_topic = "game:#{params.game_id}"
    :timer.sleep(600)

    case PhoenixClient.Channel.join(socket, game_topic) do
      {:ok, _response, channel} ->
        new_params = Map.merge(params, %{channel: channel})
        Codebattle.Bot.PlaybookPlayerRunner.call(new_params)

      {:error, reason} ->
        {:error, reason}
    end

    {:noreply, state}
  end

  # HELPERS

  def handle_info(message, state) do
    Logger.info(inspect(message))
    {:noreply, state}
  end

  defp server_name(game_id) do
    {:via, :gproc, game_key(game_id)}
  end

  defp game_key(game_id) do
    {:n, :l, {:bot_player, "#{game_id}"}}
  end

  defp bot_token(bot_id) do
    Phoenix.Token.sign(%Phoenix.Socket{endpoint: CodebattleWeb.Endpoint}, "user_token", bot_id)
  end
end
