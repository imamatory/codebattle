defmodule Codebattle.GameProcess.Player do
  @moduledoc "Struct for player"
  alias Codebattle.Languages
  # @game_result [:undefined, :gave_up, :won, :lost]

  alias Codebattle.User
  alias Codebattle.UserGame

  @derive {Poison.Encoder,
           only: [
             :id,
             :name,
             :guest,
             :is_bot,
             :github_id,
             :lang,
             :editor_mode,
             :editor_theme,
             :editor_text,
             :editor_lang,
             :output,
             :creator,
             :game_result,
             :result,
             :achievements,
             :rating,
             :rating_diff
           ]}

  defstruct id: "",
            editor_text: "module.exports = () => {\n\n};",
            editor_lang: "js",
            game_result: :undefined,
            output: "",
            result: "{}",
            creator: false,
            is_bot: false,
            github_id: "",
            public_id: "",
            name: "",
            rating: 0,
            rating_diff: 0,
            achievements: []

  def build(%UserGame{} = user_game) do
    case user_game.user do
      nil ->
        %__MODULE__{}

      user ->
        %__MODULE__{
          id: user.id,
          public_id: user.public_id,
          is_bot: user.is_bot,
          github_id: user.github_id,
          name: user.name,
          achievements: user_game.user.achievements,
          rating: user_game.rating,
          rating_diff: user_game.rating_diff,
          editor_lang: user_game.lang,
          creator: user_game.creator,
          game_result: user_game.result
        }
    end
  end

  def build(%User{} = user, params \\ %{}) do
    player =
      case user.id do
        nil ->
          %__MODULE__{}

        _ ->
          editor_lang = user.lang || "js"
          editor_text = Languages.get_solution(editor_lang)

          %__MODULE__{
            id: user.id,
            public_id: user.public_id,
            is_bot: user.is_bot,
            github_id: user.github_id,
            name: user.name,
            rating: user.rating,
            editor_lang: editor_lang,
            editor_text: editor_text,
            achievements: user.achievements
          }
      end

    Map.merge(player, params)
  end
end
