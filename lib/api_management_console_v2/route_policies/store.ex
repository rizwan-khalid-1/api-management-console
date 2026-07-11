defmodule ApiManagementConsoleV2.RoutePolicies.Store do
  @moduledoc false

  require Logger

  import ApiManagementConsoleV2.Debug, only: [log: 1]

  @db_name :api_policies_db
  @hidden_prefix "__hidden__"
  @selection_key "__free_selection__"

  def all do
    CubDB.select(@db_name)
    |> Stream.reject(fn {k, _} -> is_binary(k) and String.starts_with?(k, @hidden_prefix) end)
    |> Enum.to_list()
  rescue
    _ -> []
  end

  def put(key, enabled) do
    toggle(key, enabled)
  end

  def toggle(key, enabled) do
    log("[ApiStore] toggle — key=#{key}, enabled=#{enabled}")

    CubDB.transaction(@db_name, fn tx ->
      current = CubDB.Tx.get(tx, key)
      current = if is_nil(current), do: true, else: current
      tx = CubDB.Tx.put(tx, key, enabled)
      {:commit, tx, current}
    end)
  end

  def toggle_group(keys, enabled) when is_list(keys) do
    log("[ApiStore] toggle_group — keys=#{length(keys)}, enabled=#{enabled}")

    CubDB.transaction(@db_name, fn tx ->
      {tx, results} =
        Enum.reduce(keys, {tx, []}, fn key, {tx, acc} ->
          current = CubDB.Tx.get(tx, key)
          current = if is_nil(current), do: true, else: current
          tx = CubDB.Tx.put(tx, key, enabled)
          {tx, [{key, current} | acc]}
        end)

      {:commit, tx, Enum.reverse(results)}
    end)
  end

  def bulk_put(updates) when is_list(updates) do
    CubDB.transaction(@db_name, fn tx ->
      {tx, results} =
        Enum.reduce(updates, {tx, []}, fn {key, enabled}, {tx, acc} ->
          current = CubDB.Tx.get(tx, key)
          current = if is_nil(current), do: true, else: current
          tx = CubDB.Tx.put(tx, key, enabled)
          {tx, [{key, current} | acc]}
        end)

      {:commit, tx, Enum.reverse(results)}
    end)
  end

  def reset_all do
    # Preserve the selection key before clearing
    selection =
      case CubDB.get(@db_name, @selection_key) do
        nil -> MapSet.new()
        sel -> sel
      end

    CubDB.clear(@db_name)

    # Restore selection after clear
    if MapSet.size(selection) > 0 do
      CubDB.put(@db_name, @selection_key, selection)
    end

    :ok
  rescue
    _ ->
      CubDB.clear(@db_name)
      :ok
  end

  def enabled?(key) do
    case CubDB.get(@db_name, key) do
      nil -> true
      enabled -> enabled
    end
  rescue
    _ -> true
  end

  def hide(keys) when is_list(keys) do
    updates = Map.new(keys, fn k -> {hidden_key(k), true} end)
    CubDB.put_multi(@db_name, updates)
    :ok
  end

  def show(keys) when is_list(keys) do
    keys
    |> Enum.each(fn k -> CubDB.delete(@db_name, hidden_key(k)) end)
    :ok
  end

  def hidden_keys do
    CubDB.select(@db_name)
    |> Stream.filter(fn {k, _} -> is_binary(k) and String.starts_with?(k, @hidden_prefix) end)
    |> Stream.map(fn {k, _} -> String.replace_prefix(k, @hidden_prefix, "") end)
    |> Enum.to_list()
  rescue
    _ -> []
  end

  def hidden_count do
    CubDB.select(@db_name)
    |> Stream.filter(fn {k, _} -> is_binary(k) and String.starts_with?(k, @hidden_prefix) end)
    |> Enum.count()
  rescue
    _ -> 0
  end

  defp hidden_key(key), do: @hidden_prefix <> key

  # --- Route Selection (Free Tier) ---

  @doc "Returns the current route selection as a MapSet of route keys."
  def get_selection do
    case CubDB.get(@db_name, @selection_key) do
      nil -> MapSet.new()
      selection -> selection
    end
  rescue
    _ -> MapSet.new()
  end

  @doc "Sets the route selection atomically."
  def set_selection(keys) do
    CubDB.transaction(@db_name, fn tx ->
      tx = CubDB.Tx.put(tx, @selection_key, MapSet.new(keys))
      {:commit, tx, :ok}
    end)
  end

  @doc "Adds keys to the selection atomically."
  def add_to_selection(keys) do
    CubDB.transaction(@db_name, fn tx ->
      current = CubDB.Tx.get(tx, @selection_key) || MapSet.new()
      updated = Enum.reduce(keys, current, &MapSet.put(&2, &1))
      tx = CubDB.Tx.put(tx, @selection_key, updated)
      {:commit, tx, :ok}
    end)
  end

  @doc "Removes keys from the selection atomically."
  def remove_from_selection(keys) do
    CubDB.transaction(@db_name, fn tx ->
      current = CubDB.Tx.get(tx, @selection_key) || MapSet.new()
      updated = Enum.reduce(keys, current, &MapSet.delete(&2, &1))
      tx = CubDB.Tx.put(tx, @selection_key, updated)
      {:commit, tx, :ok}
    end)
  end
end
