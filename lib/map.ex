defmodule VindApi.Map do
  def put_merged(m1, key, m2) when is_map(m1) and is_map(m2) and is_atom(key) do
    Map.merge(
      m1,
      Map.put(%{}, key, m2),
      fn ^key, m1, m2 ->
        Map.merge(m1, m2)
      end
    )
  end
end
