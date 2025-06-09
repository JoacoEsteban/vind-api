defmodule VindApiWeb.PageController do
  use VindApiWeb, :controller

  def resources_index(conn, _params) do
    # The home page is often custom made,
    # so skip the default app layout.

    posts =
      VindApiWeb.PageHTML.all_posts()
      |> Enum.map(fn {_, slug, _, front_matter, _last_modified} ->
        %{url: "/resources/" <> slug, front_matter: front_matter}
      end)
      |> Enum.sort_by(&DateTimeParser.parse_date!(Map.get(&1, :front_matter)[:date]), :desc)

    render(conn, :resources_index,
      posts: posts,
      layout: false,
      page_title: "Resources"
    )
  end

  def render_framer(conn, _params) do
    {:ok, body} =
      VindApiWeb.WebEmbeds.render(conn.request_path)

    html(conn, body)
  end

  def render_doc(conn, params) do
    id = params["id"]

    conn
    |> render(
      id <> ".html",
      conn |> get_front_matter(id)
    )
  end

  defp get_front_matter(conn, id) do
    module = view_module(conn)
    function_name = String.to_atom(id <> "_front_matter")

    if Kernel.function_exported?(module, function_name, 0) do
      apply(module, function_name, [])
    else
      IO.warn("Front matter not exposed for template " <> id)
      []
    end
  end
end
