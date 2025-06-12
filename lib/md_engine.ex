defmodule VindApi.MdEngine do
  @behaviour Phoenix.Template.Engine

  def read_document(path) do
    {attrs, html_body} =
      path
      |> File.read!()
      |> split_contents()

    last_modified = fn -> VindApi.GitHelpers.last_modified(:date, path) end

    {attrs, html_body, last_modified}
  end

  def compile(path, _name, compiler_opts \\ []) do
    {_, html_body, _} =
      read_document(path)

    EEx.compile_string(
      html_body.(compiler_opts),
      engine: Phoenix.HTML.Engine,
      file: path,
      line: 1
    )
  end

  defp split_contents(contents) do
    [front_matter, markdown_body] = String.split(contents, "---\n", trim: true, parts: 2)

    attrs = fn opts ->
      transformations =
        Keyword.get(opts, :asset_transformations)

      parse_yaml(front_matter)
      |> Enum.map(fn {key, value} = tuple ->
        case get_transformed_img(value, transformations) do
          {:noop, _} -> tuple
          {:ok, transformed} -> {key, transformed}
        end
      end)
    end

    html_body = fn opts ->
      markdown_to_html!(markdown_body, opts)
    end

    {attrs, html_body}
  end

  defp markdown_to_html!(markdown_body, opts \\ []) do
    {:ok, _} = Application.ensure_all_started(:fast_html)

    EarmarkParser.as_ast(markdown_body, math: true, code_class_prefix: "lang-")
    |> case do
      {:ok, ast, _} -> ast
    end
    |> Earmark.Transform.map_ast(fn node ->
      process_html_node(node, opts)
    end)
    |> earmark_to_floki()
    |> Floki.raw_html()
  end

  defp process_html_node({"code", [{"class", "math-inline"}], [text], meta}, _) do
    # Render math expression
    math_exp_ast =
      VindApi.MathJaxRenderer.render_to_mathml(text)
      |> case do
        {:ok, result} -> result
      end
      |> Floki.parse_fragment!(parser_args: [preserve_whitespace: true])
      |> floki_to_earmark()

    {:replace, {"span", [{"class", "math-inline"}], [math_exp_ast], meta}}
  end

  defp process_html_node({"pre", _, [{"code", code_attrs, [body], _}], _}, _) do
    # Highlight code
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

    {:replace,
     Autumn.highlight!(body, language: lang, theme: "material_darker")
     |> Floki.parse_fragment!(parser_args: [preserve_whitespace: true])
     |> floki_to_earmark()}
  end

  defp process_html_node({"img", attrs, body, meta} = node, opts) do
    {"src", src} = List.keyfind(attrs, "src", 0)

    transformations =
      Keyword.get(opts, :asset_transformations)

    case get_transformed_img(src, transformations) do
      {:noop, _} ->
        node

      {:ok, new_src} ->
        new_attrs =
          attrs
          |> List.keyreplace("src", 0, {"src", new_src})

        {"img", new_attrs, body, meta}
    end
  end

  defp process_html_node(node, _) do
    node
  end

  defp get_transformed_img(src, transformations) do
    case transformations[src] do
      nil ->
        {:noop, src}

      exec ->
        {:ok, %{file_name: file_name, output_name: output_name}} =
          exec.()

        new_src =
          src
          |> String.replace(file_name, output_name)

        {:ok, new_src}
    end
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

  @static_dir Application.app_dir(:vind_api, "priv/static")
  @assets_directory_name "assets"

  @doc type: :macro
  defmacro embed_templates(pattern, opts \\ []) do
    IO.inspect(pattern)

    quote bind_quoted: [pattern: pattern, opts: opts] do
      root = Path.expand(opts[:root] || __DIR__, __DIR__)

      transformations =
        VindApi.TemplateMacros.copy_assets(
          pattern,
          root,
          opts[:assets_output_directory_name]
        )

      VindApi.TemplateMacros.compile_all(
        &Phoenix.Template.__embed__(&1, opts[:suffix]),
        root,
        pattern,
        opts
        |> Keyword.put(:asset_transformations, transformations)
      )
    end
  end

  def copy_assets(_pattern, _root, output_path) when is_nil(output_path) do
  end

  def copy_assets(pattern, root, output_path) do
    assets_source =
      Path.join(root, pattern)
      |> String.split("*", parts: 2)
      |> List.first()
      |> Path.join(@assets_directory_name)

    assets_destination =
      @static_dir
      |> Path.join(output_path)
      |> Path.join(@assets_directory_name)

    File.mkdir_p(assets_destination)

    transformations =
      with true <- File.exists?(assets_source),
           {:ok, files} <- File.ls(assets_source) do
        Enum.reduce(files, %{}, fn file, transformations ->
          source = Path.join(assets_source, file)

          val =
            with true <- File.regular?(source) do
              destination = Path.join(assets_destination, file)


              File.cp!(source, destination)

              if should_transform?(destination) do
                key = Path.join(@assets_directory_name, file)

                transformations
                |> Map.put(key, fn -> transform_image(destination) end)
              end
            end

          case val do
            nil -> transformations
            value -> value
          end
        end)
      else
        _ -> %{}
      end

    transformations
  end

  defp should_transform?(file) do
    ["jpg", "png"]
    |> Enum.any?(&String.ends_with?(file, "." <> &1))
  end

  defp transform_image(file_path, quality \\ 50) do
    {_hash_key, hashed_part} = hash_file_path(file_path, quality)

    output_path =
      file_path
      |> change_extension("webp", "_" <> hashed_part)

    if !File.exists?(output_path) do
      file_path
      |> Image.open!()
      |> Image.write!(output_path, quality: quality)
    end

    {:ok,
     %{
       file_path: file_path,
       output_path: output_path,
       file_name: Path.basename(file_path),
       output_name: Path.basename(output_path)
     }}
  end

  defp change_extension(file_path, new_extension) do
    change_extension(file_path, new_extension, "")
  end

  defp change_extension(file_path, new_extension, suffix) do
    file_path
    |> Path.dirname()
    |> Path.join(
      Path.basename(
        file_path,
        Path.extname(file_path)
      ) <>
        suffix <>
        "." <> new_extension
    )
  end

  defp hash_file_path(file_path, webp_quality) do
    with quality <- Integer.to_string(webp_quality),
         key <- file_path <> quality do
      {
        key,
        :crypto.hash(:md5, key)
        |> Base.encode16(case: :lower)
      }
    end
  end

  defmacro compile_all(converter, root, pattern, opts \\ [], engines \\ nil) do
    quote bind_quoted: binding() do
      templates =
        VindApi.TemplateMacros.__compile_all__(
          __MODULE__,
          converter,
          root,
          pattern,
          engines,
          opts
        )

      case Keyword.get(opts, :list_embed_key) do
        key when is_atom(key) ->
          def unquote(key)() do
            unquote(Macro.escape(templates))
          end

        _ ->
          nil
      end

      for {path, name, body, front_matter, last_modified} <-
            templates do
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

        if last_modified != nil do
          def unquote(String.to_atom(name <> "_last_modified"))() do
            unquote(Macro.escape(last_modified))
          end
        end

        {name, path}
      end
    end
  end

  def __compile_all__(module, converter, root, pattern, given_engines, opts \\ []) do
    engines = given_engines || engines()

    paths = find_all(root, pattern, engines)

    {triplets, {paths, engines}} =
      Enum.map_reduce(paths, {[], %{}}, fn path, {acc_paths, acc_engines} ->
        ext = Path.extname(path) |> String.trim_leading(".") |> String.to_atom()
        engine = Map.fetch!(engines, ext)
        name = converter.(path)

        {front_matter, body, last_modified} =
          case engine do
            VindApi.MdEngine ->
              {fm, _, last_modified} = engine.read_document(path)

              {fm.(opts), engine.compile(path, name, opts), last_modified.()}

            _ ->
              {nil, engine.compile(path, name), nil}
          end

        map = {path, name, body, front_matter, last_modified}
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
