defmodule ApiManagementConsoleV2.RoutePolicies.Store do
  @moduledoc false

  require Logger

  import ApiManagementConsoleV2.Debug, only: [log: 1]

  @db_name :api_policies_db
  @hidden_prefix "__hidden__"

  defp data_dir do
    dir = Application.get_env(:api_management_console, :storage_dir, "api-console-data")
    Path.join(dir, "api_policies")
  end

  def start_link(_opts \\ []) do
    CubDB.start_link(data_dir: data_dir(), name: @db_name)
  end

  def all do
    CubDB.select(@db_name)
    |> Stream.reject(fn {k, _} -> is_binary(k) and String.starts_with?(k, @hidden_prefix) end)
    |> Enum.to_list()
  rescue
    _ -> []
  end

  def put(key, enabled) do
    log("[ApiStore] put — key=#{key}, enabled=#{enabled}")
    CubDB.put(@db_name, key, enabled)
    :ok
  end

  def bulk_put(updates) when is_list(updates) do
    CubDB.put_multi(@db_name, Map.new(updates))
    :ok
  end

  def reset_all do
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
end
