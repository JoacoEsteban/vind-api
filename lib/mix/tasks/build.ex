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

      now =
        DateTime.utc_now()
        |> Calendar.strftime("%Y-%m-%d")

      resources = "/resources/"

      routes =
        VindApiWeb.PageHTML.all_posts()
        |> Enum.map(fn {_path, name, _body, _front_matter, last_modified} ->
          date =
            case last_modified do
              {:ok, date} ->
                date

              {:error, :date_empty} ->
                now
            end

          {name, date}
        end)
        |> Enum.map(fn {name, last_modified} -> {resources <> name, last_modified} end)

      {_, newest} = Enum.max_by(routes, fn {_path, last_modified} -> last_modified end)

      VindApi.StaticBuilder.build([{"/", now}, {resources, newest} | routes])
    end
  end
end
