defmodule VindApi.MathJaxRenderer do
  @moduledoc """
  Server-side MathJax rendering using Node.js
  """

  def render_latex(math_string, options \\ %{}) do
    {:ok, _pid} = ensure_node_started()

    default_options = %{
      math: math_string,
      format: "TeX",
      svg: true,
      mml: true
    }

    merged_options = Map.merge(default_options, options)

    path_to_wrapper =
      Path.join([File.cwd!(), "lib/node_bridge", "mathjax_wrapper.js"])
      |> IO.inspect()

    case NodeJS.call({path_to_wrapper, :typeset}, [merged_options]) do
      {:ok, result} -> {:ok, result}
      {:error, reason} -> {:error, reason}
    end
  end

  def render_to_svg(math_string) do
    case render_latex(math_string, %{svg: true, html: false, mml: false}) do
      {:ok, %{"svg" => svg}} -> {:ok, svg}
      {:error, reason} -> {:error, reason}
    end
  end

  def render_to_mathml(math_string) do
    case render_latex(math_string, %{mml: true, svg: false, html: false}) do
      {:ok, %{"mml" => mml}} -> {:ok, mml}
      {:error, reason} -> {:error, reason}
    end
  end

  defp ensure_node_started do
    {:ok, _} =
      Application.ensure_all_started(:nodejs)

    case NodeJS.Supervisor.start_link(
           path: "./node_modules",
           pool_size: 4
         ) do
      {:ok, pid} ->
        {:ok, pid}

      {:error, {:already_started, pid}} ->
        {:ok, pid}
    end
  end
end
