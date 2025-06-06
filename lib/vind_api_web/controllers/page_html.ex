defmodule VindApiWeb.PageHTML do
  require VindApi.TemplateMacros
  use VindApiWeb, :html

  VindApi.TemplateMacros.embed_templates("page_html/*")
  VindApi.TemplateMacros.embed_templates("vind-docs/*", list_embed_key: :all_posts)
end
