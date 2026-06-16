defmodule ApiManagementConsoleV2.AuditLog.Store do
  @moduledoc false

  require Logger

  defp dets_file do
    dir = Application.get_env(:api_management_console, :storage_dir, "tmp")
    Path.join(dir, "api_audit.dets")
  end

  # Counter key for auto-incrementing IDs
  @counter_key :__audit_counter__

  defp table do
    case :dets.open_file(String.to_charlist(dets_file()), type: :set) do
      {:ok, ref} -> ref
      {:error, reason} -> raise "Failed to open audit DETS: #{inspect(reason)}"
    end
  end

  def append(entry) do
    ref = table()
    id = next_id(ref)
    :dets.insert(ref, {counter_id(), id})
    :dets.insert(ref, {id, entry})
    :dets.sync(ref)
    :dets.close(ref)

    Logger.debug("[AuditStore] append — id=#{id}, key=#{entry.key}, #{entry.old_state} → #{entry.new_state}")
    :ok
  end

  def list(offset, limit) do
    ref = table()
    total = current_count(ref)

    entries =
      ref
      |> :dets.match({:"$1", :"$2"})
      |> Enum.reject(fn [k, _v] -> k == counter_id() end)
      |> Enum.sort_by(fn [id, _] -> id end, :desc)
      |> Enum.drop(offset)
      |> Enum.take(limit)
      |> Enum.map(fn [_id, entry] -> entry end)

    :dets.close(ref)
    {entries, total}
  end

  def count do
    ref = table()
    c = current_count(ref)
    :dets.close(ref)
    c
  end

  # --- Private ---

  defp counter_id, do: @counter_key

  defp next_id(ref) do
    case :dets.lookup(ref, counter_id()) do
      [{_k, n}] ->
        n + 1
      [] ->
        1
    end
  end

  defp current_count(ref) do
    case :dets.lookup(ref, counter_id()) do
      [{_k, n}] -> n
      [] -> 0
    end
  end
end
