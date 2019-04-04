defmodule Codebattle.CodeCheck.Checker do
  @moduledoc false

  require Logger

  alias Codebattle.Languages
  # alias Codebattle.CodeCheck.OutputFilter

  def check(task, editor_text, editor_lang) do
    case Languages.meta() |> Map.get(editor_lang) do
      nil ->
        {:error, "Lang #{editor_lang} is undefined"}

      lang ->
        # TODO: add hash to data.jsons or forbid read data.jsons
        docker_command_template =
          case lang.base_image do
            :ubuntu ->
              Application.fetch_env!(:codebattle, :ubuntu_docker_command_template)

            :alpine ->
              Application.fetch_env!(:codebattle, :alpine_docker_command_template)
          end

        {dir_path, check_code} = prepare_tmp_dir!(task, editor_text, lang)
        volume = "-v #{dir_path}:/usr/src/app/#{lang.check_dir}"

        command =
          docker_command_template
          |> :io_lib.format([volume, lang.docker_image])
          |> to_string

        Logger.debug(command)
        [cmd | cmd_opts] = command |> String.split()
        t = :os.system_time(:millisecond)
        {container_output, _status} = System.cmd(cmd, cmd_opts, stderr_to_stdout: true)
        Logger.error("Execution time: #{:os.system_time(:millisecond) - t}, lang: #{lang.slug}")

        Logger.debug(
          "Docker stdout for task_id: #{task.id}, lang: #{lang.slug}, output:#{container_output}"
        )

        # for json returned langs need fix after all langs support json
        json_result =
          case Regex.run(~r/{\"status\":.+}/, container_output) do
            nil ->
              Jason.encode!(%{
                status: "error",
                result: "Something went wrong! Please, write to dev team in our Slack"
              })

            arr ->
              List.first(arr)
          end

        output_code = Regex.named_captures(~r/__code(?<code>.+)__/, json_result)["code"]

        result =
          case output_code do
            ^check_code -> {:ok, json_result, container_output}
            _ -> {:error, json_result, container_output}
          end

        Task.start(File, :rm_rf, [dir_path])
        result
    end
  end

  defp prepare_tmp_dir!(task, editor_text, lang) do
    dir_path = Temp.mkdir!(prefix: "codebattle-check")

    check_code = :rand.normal() |> to_string

    file_name =
      case lang.slug do
        "haskell" ->
          "Solution.#{lang.extension}"

        _ ->
          "solution.#{lang.extension}"
      end

    asserts = task.asserts <> "{\"check\":\"__code#{check_code}__\"}"
    File.write!(Path.join(dir_path, "data.jsons"), asserts)

    File.write!(Path.join(dir_path, file_name), editor_text)
    {dir_path, check_code}
  end
end
