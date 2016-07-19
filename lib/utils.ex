defmodule Utils do
    use RethinkDB.Connection
    import List , only: [first: 1]

    def handle_graphql_resp(obj) do
        obj |> strip_data |> strip_wrapper |> convert_to_atoms
    end

    defp strip_data({ :ok, data }), do: data

    defp strip_wrapper(%{data: nil}), do: %{}
    defp strip_wrapper(%{data: doc}), do: doc
    defp strip_wrapper(_anything), do: %{}

    defp convert_to_atoms(data) when is_list(data) do
        Enum.map(data, fn (doc) ->
            for {key, val} <- doc, into: %{} do
                cond do
                    is_atom(key) -> {key, val}
                    true -> {String.to_atom(key), val}
                end
            end
        end)
    end

    defp convert_to_atoms(doc) when is_map(doc) do
        for {key, val} <- doc, into: %{} do
            cond do
                is_atom(key) -> {key, val}
                true -> {String.to_atom(key), val}
            end
        end
    end

end
