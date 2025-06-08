defmodule VindApi.GitHelpers do
  @moduledoc """
  Provides a function to get the last modified time of a tracked file in a Git repository,
  including files inside submodules by changing directory to the file's directory.
  """

  @doc """
  Returns the last modified time of the given file as a string.

  The function receives a single file path, changes directory to the file's directory,
  and runs the git log command on the file name.

  ## Examples

      iex> VindApi.GitHelpers.last_modified("lib/myfile.ex")
      "2025-06-08 12:34:56 +0000"

      iex> VindApi.GitHelpers.last_modified("deps/my_submodule/src/foo.ex")
      "2025-06-07 11:22:33 +0000"
  """
  def last_modified(file_path) do
    exec(file_path)
  end

  def last_modified(:date, file_path) do
    with {:ok, date} <- last_modified(file_path),
         date <-
           date
           |> String.split(" ")
           |> List.first()
           |> String.trim() do
      {:ok, date}
    end
  end

  defp exec(file_path) do
    dir = Path.dirname(file_path)
    file = Path.basename(file_path)

    {output, 0} =
      System.cmd(
        "git",
        ["log", "-1", "--format=%ci", file],
        cd: dir
      )

    case output |> String.trim() do
      "" -> {:error, :date_empty}
      val when is_binary(val) -> {:ok, val}
      _ -> {:error, :unknown}
    end
  end
end
