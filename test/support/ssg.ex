defmodule VindApi.StaticBuilder do
  import Phoenix.HTML
  require Phoenix.Template
  require Phoenix.LiveViewTest
  use VindApiWeb.ConnCase

  @output_dir "./dist"
  @canonical "https://vind-works.io"

  Phoenix.Template.embed_templates("templates/*")

  def build(routes) do
    File.mkdir_p!(@output_dir)
    copy_static_assets()

    for {route, _last_modified} <- routes do
      conn = build_conn()
      conn = get(conn, route)
      content = html_response(conn, 200)

      write_file(
        route_to_file_path(route),
        content
      )
    end

    write_file(
      "sitemap.xml",
      render_sitemap(routes)
    )
  end

  defp render_sitemap(routes) do
    Phoenix.LiveViewTest.render_component(&sitemap/1, %{
      routes: routes,
      canonical: @canonical
    })
  end

  defp write_file(file_path, content) do
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
