defmodule Mix.Tasks.Build do
  use Mix.Task

  defmacro with_timing(do: block) do
    quote do
      start_time = System.monotonic_time()

      value = unquote(block)

      end_time = System.monotonic_time()
      elapsed = System.convert_time_unit(end_time - start_time, :native, :millisecond)
      IO.puts("Built in #{elapsed} milliseconds")

      value
    end
  end

  def run(_) do
    with_timing do
      Mix.Task.run("app.start")

      resources = "/resources/"

      routes =
        VindApiWeb.PageHTML.all_posts()
        |> Enum.map(fn {_path, name, _body, _front_matter} -> name end)
        |> Enum.map(fn name -> resources <> name end)

      VindApi.StaticBuilder.build(["/", resources | routes])
    end
  end
end
