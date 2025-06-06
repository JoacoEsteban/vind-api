defmodule VindApi.MdEngine do
  @behaviour Phoenix.Template.Engine

  def read_document(path) do
    path
    |> File.read!()
    |> split_contents
  end

  def compile(path, _name) do
    {_, html_body} =
      read_document(path)

    EEx.compile_string(
      html_body.(),
      engine: Phoenix.HTML.Engine,
      file: path,
      line: 1
    )
  end

  defp split_contents(contents) do
    [front_matter, markdown_body] = String.split(contents, "---\n", trim: true, parts: 2)

    attrs = fn -> parse_yaml(front_matter) end
    html_body = fn -> markdown_to_html!(markdown_body) end

    {attrs, html_body}
  end

  defp markdown_to_html!(markdown_body) do
    Earmark.Parser.as_ast(markdown_body, sub_sup: true, math: true, code_class_prefix: "lang-")
    |> (fn {:ok, ast, _} -> ast end).()
    |> Earmark.Transform.map_ast(&highlight_code/1)
    |> earmark_to_floki()
    |> Floki.raw_html()
  end

  defp highlight_code({"pre", _, [{"code", code_attrs, [body], _}], _}) do
    lang =
      code_attrs
      |> List.keyfind("class", 0)
      |> case do
        {"class", value} ->
          value
          |> String.split(" ")
          |> Enum.find(&String.starts_with?(&1, "lang-"))
          |> case do
            lang when is_binary(lang) ->
              String.replace_prefix(lang, "lang-", "")

            _ ->
              nil
          end

        _ ->
          "plaintext"
      end

    {:ok, _} = Application.ensure_all_started(:fast_html)

    {:replace,
     Autumn.highlight!(body, language: lang, theme: "material_darker")
     |> Floki.parse_fragment!(parser_args: [preserve_whitespace: true])
     |> floki_to_earmark()}
  end

  defp highlight_code(node) do
    node
  end

  defp earmark_to_floki(node) do
    case node do
      {tag, attrs, children, _} ->
        {tag, attrs, Enum.map(children, &earmark_to_floki/1)}

      {node, false} ->
        earmark_to_floki(node)

      [node | tail] ->
        [earmark_to_floki(node) | earmark_to_floki(tail)]

      node ->
        node
    end
  end

  defp floki_to_earmark(node) do
    case node do
      {tag, attrs, children} ->
        {tag, attrs, Enum.map(children, &floki_to_earmark/1), %{}}

      [node] ->
        floki_to_earmark(node)

      node ->
        node
    end
  end

  # --------------------------------------------------------

  defp parse_yaml(content) when is_binary(content) do
    parse_yaml_lines(
      String.split(content, "\n"),
      []
    )
  end

  defp parse_yaml_lines([], map) do
    map
  end

  defp parse_yaml_lines([line | lines], map) do
    parse_yaml_lines(
      lines,
      if String.contains?(line, ":") do
        [key, value] =
          String.split(line, ":", parts: 2) |> Enum.map(&String.trim/1)

        [{String.to_atom(key), value} | map]
      else
        map
      end
    )
  end
end

defmodule VindApi.TemplateMacros do
  require Phoenix.Template
  import Phoenix.Template

  @doc type: :macro
  defmacro embed_templates(pattern, opts \\ []) do
    IO.inspect(pattern)

    quote bind_quoted: [pattern: pattern, opts: opts] do
      VindApi.TemplateMacros.compile_all(
        &Phoenix.Template.__embed__(&1, opts[:suffix]),
        Path.expand(opts[:root] || __DIR__, __DIR__),
        pattern
      )
    end
  end

  defmacro compile_all(converter, root, pattern, engines \\ nil) do
    quote bind_quoted: binding() do
      for {path, name, body, front_matter} <-
            VindApi.TemplateMacros.__compile_all__(__MODULE__, converter, root, pattern, engines) do
        IO.inspect(String.to_atom(name), label: "ATOM")
        @external_resource path
        @file path
        def unquote(String.to_atom(name))(var!(assigns)) do
          _ = var!(assigns)
          unquote(body)
        end

        if front_matter != nil do
          def unquote(String.to_atom(name <> "_front_matter"))() do
            unquote(Macro.escape(front_matter))
          end
        end

        {name, path}
      end
    end
  end

  def __compile_all__(module, converter, root, pattern, given_engines) do
    engines = given_engines || engines()

    paths = find_all(root, pattern, engines)

    {triplets, {paths, engines}} =
      Enum.map_reduce(paths, {[], %{}}, fn path, {acc_paths, acc_engines} ->
        ext = Path.extname(path) |> String.trim_leading(".") |> String.to_atom()
        engine = Map.fetch!(engines, ext)
        name = converter.(path)
        body = engine.compile(path, name)

        front_matter =
          case engine do
            VindApi.MdEngine ->
              {fm, _} = engine.read_document(path)
              fm.()

            _ ->
              nil
          end

        map = {path, name, body, front_matter}
        reduce = {[path | acc_paths], Map.put(acc_engines, engine, true)}
        {map, reduce}
      end)

    # Store the engines so we define compile-time deps
    Phoenix.Template.__idempotent_setup__(module, engines)

    # Store the hashes so we define __mix_recompile__?
    hash = paths |> Enum.sort() |> :erlang.md5()

    args =
      if given_engines, do: [root, pattern, Macro.escape(given_engines)], else: [root, pattern]

    Module.put_attribute(module, :phoenix_templates_hashes, {hash, args})
    triplets
  end
end
