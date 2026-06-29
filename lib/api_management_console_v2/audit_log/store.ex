defmodule ApiManagementConsoleV2.AuditLog.Store do
  @moduledoc false

  require Logger

  import ApiManagementConsoleV2.Debug, only: [log: 1]

  @db_name :api_audit_db

  def append(entry) do
    # Use timestamp + random suffix as unique key
    key = "#{System.system_time(:millisecond)}_#{:rand.uniform(999_999)}"
    CubDB.put(@db_name, key, entry)

    log("[AuditStore] append — key=#{entry.key}, #{entry.old_state} → #{entry.new_state}")
    :ok
  end

  def list(offset, limit) do
    entries =
      CubDB.select(@db_name, reverse: true)
      |> Stream.drop(offset)
      |> Stream.take(limit)
      |> Stream.map(fn {_key, entry} -> entry end)
      |> Enum.to_list()

    total = CubDB.size(@db_name)
    {entries, total}
  end

  def count do
    CubDB.size(@db_name)
  end
end
