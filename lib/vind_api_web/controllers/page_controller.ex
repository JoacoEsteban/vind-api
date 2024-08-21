defmodule VindApiWeb.PageController do
  use VindApiWeb, :controller

  def home(conn, _params) do
    # The home page is often custom made,
    # so skip the default app layout.
    render(conn, :home, layout: false)
  end

  def render_framer(conn, _params) do
    {:ok, body} =
      VindApiWeb.WebEmbeds.render(conn.request_path)

    html(conn, body)
  end
end
