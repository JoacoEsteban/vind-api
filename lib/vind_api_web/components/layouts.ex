defmodule VindApiWeb.Layouts do
  @moduledoc """
  This module holds different layouts used by your application.

  See the `layouts` directory for all templates available.
  The "root" layout is a skeleton rendered as part of the
  application router. The "app" layout is set as the default
  layout on both `use VindApiWeb, :controller` and
  `use VindApiWeb, :live_view`.
  """
  use VindApiWeb, :html

  embed_templates "layouts/*"

  def root_error(assigns) do
    root(
      assigns
      |> Map.put(:page_title, "Error " <> Integer.to_string(assigns[:status]))
      |> VindApi.Map.put_merged(
        :meta_tags,
        %{robots: "noindex, nofollow"}
      )
    )
  end
end
