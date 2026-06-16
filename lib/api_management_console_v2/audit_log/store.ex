defmodule ApiManagementConsoleV2.AuditLog.Store do
  @moduledoc false

  require Logger

  @db_name :api_audit_db

  defp data_dir do
    dir = Application.get_env(:api_management_console, :storage_dir, "tmp")
    Path.join(dir, "api_audit")
  end

  def start_link(_opts \\ []) do
    CubDB.start_link(data_dir: data_dir(), name: @db_name)
  end

  def append(entry) do
    # Use timestamp + random suffix as unique key
    key = "#{System.system_time(:millisecond)}_#{:rand.uniform(999_999)}"
    CubDB.put(@db_name, key, entry)

    Logger.debug("[AuditStore] append — key=#{entry.key}, #{entry.old_state} → #{entry.new_state}")
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
