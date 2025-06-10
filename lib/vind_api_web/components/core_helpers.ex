defmodule VindApiWeb.CoreHelpers do
  use PhoenixHTMLHelpers

  def render_tags_all(tags) do
    render_tags_map(tags)
  end

  defp render_tags_map(map) do
    map
    |> Enum.map(fn
      {atom, v} when is_atom(atom) -> {Atom.to_string(atom), v}
      v -> v
    end)
    |> Enum.map(fn
      {"twitter:" <> _ = k, v} -> tag(:meta, content: v, name: k)
      {k, v} -> tag(:meta, content: v, property: k)
    end)
    |> Enum.map(fn
      # Add line break
      {key, list} -> {key, list ++ [10]}
    end)
  end
end
