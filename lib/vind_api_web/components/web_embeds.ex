defmodule VindApiWeb.WebEmbeds do
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
        {tag = "head", attrs, children} ->
          {tag, attrs,
           [
             {"meta", [{"name", "robots"}, {"content", "index, follow"}], []},
             {"link", [{"rel", "canonical"}, {"href", "canonicalUrl"}], []},
             {"meta", [{"property", "og:url"}, {"content", "${canonicalUrl}"}], []},
             {"script",
              ["async", {"src", "https://www.googletagmanager.com/gtag/js?id=G-8CSQWH3SSP"}], []},
             {"script", [],
              "window.dataLayer = window.dataLayer || [];	function gtag(){dataLayer.push(arguments);}	gtag('js', new Date());	gtag('config', 'G-8CSQWH3SSP');"}
             | children
           ]}

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
