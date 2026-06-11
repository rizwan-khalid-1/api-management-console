defmodule ApiManagementConsoleV2.RoutePolicies.Store do
  @moduledoc false

  require Logger

  @dets_file "tmp/api_policies.dets"

  defp table do
    case :dets.open_file(String.to_charlist(@dets_file), type: :set) do
      {:ok, ref} ->
        ref

      {:error, reason} ->
        raise "Failed to open DETS table #{@dets_file}: #{inspect(reason)}"
    end
  end

  def all do
    ref = table()
    result = :dets.match(ref, {:"$1", :"$2"})
    :dets.close(ref)
    result |> Enum.map(fn [k, v] -> {k, v} end)
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
end
