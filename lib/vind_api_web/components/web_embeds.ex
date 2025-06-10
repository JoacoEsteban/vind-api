defmodule VindApiWeb.WebEmbeds do
  @block_anchors_script Path.join(__DIR__, "/web_embeds/block_anchors.js")
  @external_resource @block_anchors_script
  @disable_js_navigation_script {
    "script",
    [],
    @block_anchors_script
    |> File.read!()
  }
  @base_url "https://powerful-direction-650027.framer.app"

  def render(path) when is_binary(path) do
    path =
      cond do
        String.starts_with?(path, "/") -> path
        path -> "/" <> path
      end

    {:ok, res} =
      Finch.build(:get, @base_url <> path)
      |> Finch.request(VindApi.Finch)

    {:ok, document} = Floki.parse_document(res.body)

    body =
      document
      |> Floki.filter_out("#__framer-badge-container")
      |> Floki.filter_out("head meta[name=robots]")
      |> Floki.filter_out("head link[rel=canonical]")
      |> Floki.filter_out("head meta[property=og:url]")
      |> Floki.filter_out("head meta[name=generator]")
      |> Floki.filter_out("head meta[name=framer-search-index]")
      |> Floki.traverse_and_update(fn
        {tag = "body", attrs, children} ->
          {tag, attrs, children ++ [@disable_js_navigation_script]}

        {tag = "style", [head = {attr_name = "data-framer-css-ssr-minified", attr_name} | attrs],
         [children]} ->
          {tag, [head | attrs],
           [children |> String.replace("h1,h2,h3,h4,h5,h6,p,figure{margin:0}", "")]}

        other ->
          other
      end)
      |> Floki.raw_html()

    {:ok, body}
  end
end
