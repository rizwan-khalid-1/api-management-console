defmodule ApiManagementConsoleV2.RoutePolicies.Store do
  @moduledoc false

  require Logger

  @hidden_prefix "__hidden__"

  defp dets_file do
    dir = Application.get_env(:api_management_console, :storage_dir, "tmp")
    Path.join(dir, "api_policies.dets")
  end

  defp table do
    case :dets.open_file(String.to_charlist(dets_file()), type: :set) do
      {:ok, ref} -> ref
      {:error, reason} -> raise "Failed to open DETS table #{dets_file()}: #{inspect(reason)}"
    end
  end

  def all do
    ref = table()
    result = :dets.match(ref, {:"$1", :"$2"})
    :dets.close(ref)
    result |> Enum.reject(fn [k, _] -> String.starts_with?(k, @hidden_prefix) end)
      |> Enum.map(fn [k, v] -> {k, v} end)
  rescue
    _ -> []
  end

  def put(key, enabled) do
    Logger.debug("[ApiStore] put — key=#{key}, enabled=#{enabled}")
    ref = table()
    :dets.insert(ref, {key, enabled})
    :dets.sync(ref)
    :dets.close(ref)
    :ok
  end

  def bulk_put(updates) when is_list(updates) do
    ref = table()
    Enum.each(updates, fn {k, v} -> :dets.insert(ref, {k, v}) end)
    :dets.sync(ref)
    :dets.close(ref)
    :ok
  end

  def reset_all do
    File.rm(dets_file())
    :ok
  end

  def enabled?(key) do
    ref = table()

    result = case :dets.lookup(ref, key) do
      [{_key, enabled}] -> enabled
      [] -> true
    end

    :dets.close(ref)
    Logger.debug("[ApiStore] enabled? — key=#{key}, result=#{result}")
    result
  rescue
    e ->
      Logger.debug("[ApiStore] enabled? — key=#{key}, error=#{inspect(e)}, defaulting to true")
      true
  end

  def hide(keys) when is_list(keys) do
    ref = table()
    Enum.each(keys, fn k -> :dets.insert(ref, {hidden_key(k), true}) end)
    :dets.sync(ref)
    :dets.close(ref)
    :ok
  end

  def show(keys) when is_list(keys) do
    ref = table()
    Enum.each(keys, fn k -> :dets.delete(ref, hidden_key(k)) end)
    :dets.sync(ref)
    :dets.close(ref)
    :ok
  end

  def hidden_keys do
    ref = table()
    result = :dets.match(ref, {:"$1", :_})
      |> List.flatten()
      |> Enum.filter(&String.starts_with?(&1, @hidden_prefix))
      |> Enum.map(&String.replace_prefix(&1, @hidden_prefix, ""))
    :dets.close(ref)
    result
  rescue
    _ -> []
  end

  def hidden_count do
    ref = table()
    result = :dets.match(ref, {:"$1", :_})
      |> Enum.count(fn [k] -> String.starts_with?(k, @hidden_prefix) end)
    :dets.close(ref)
    result
  rescue
    _ -> 0
  end

  defp hidden_key(key), do: @hidden_prefix <> key
end
