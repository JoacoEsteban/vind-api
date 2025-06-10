defmodule VindApiWeb.PageController do
  use VindApiWeb, :controller
  @splash_url "/splash-scaled.png"

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
      page_title: "Resources",
      meta_tags: %{robots: "index, follow"},
      "og:image": @splash_url,
      "twitter:image": @splash_url
    )
  end

  def render_framer(conn, _params) do
    {:ok, body} =
      VindApiWeb.WebEmbeds.render(conn.request_path)

    assign(conn, :outer_content, body)
    |> render(:empty,
      page_title: "The Ultimate Chrome Extension for Keyboard Shortcuts",
      meta_tags: %{robots: "index, follow"}
    )
  end

  def render_doc(conn, params) do
    id = params["id"]

    front_matter =
      conn
      |> get_front_matter(id)
      |> :maps.from_list()

    assigns =
      front_matter
      |> Map.put(:page_title, "Resources - " <> front_matter[:title])
      |> Map.put(:meta_tags, %{
        robots: "index, follow",
        description: front_matter[:description],
        "og:description": front_matter[:description],
        "twitter:description": front_matter[:description],
        "og:title": front_matter[:title],
        "twitter:title": front_matter[:title],
        "og:image": front_matter[:hero_img],
        "twitter:image": front_matter[:hero_img],
        "og:type": "article"
      })

    conn
    |> render(
      id <> ".html",
      assigns
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
