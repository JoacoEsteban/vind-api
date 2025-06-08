defmodule VindApi.StaticBuilder do
  use VindApiWeb.ConnCase

  @output_dir "./dist"

  def build(routes) do
    File.mkdir_p!(@output_dir)
    copy_static_assets()

    for route <- routes do
      conn = build_conn()
      conn = get(conn, route)
      content = html_response(conn, 200)

      write_route(route, content)
    end
  end

  defp write_route(route, content) do
    file_path = route_to_file_path(route)
    dir = Path.dirname(file_path)

    unless dir == ".", do: File.mkdir_p!(Path.join(@output_dir, dir))
    File.write!(Path.join(@output_dir, file_path), content)
  end

  defp route_to_file_path("/"), do: "index.html"

  defp route_to_file_path(route) do
    route
    |> String.trim_leading("/")
    |> then(fn name ->
      case String.ends_with?(name, "/") do
        true -> name <> "index"
        _ -> name
      end
    end)
    |> Kernel.<>(".html")
  end

  defp copy_static_assets do
    static_dir = Application.app_dir(:vind_api, "priv/static")

    if File.exists?(static_dir) do
      File.cp_r!(static_dir, @output_dir)
    end
  end
end
