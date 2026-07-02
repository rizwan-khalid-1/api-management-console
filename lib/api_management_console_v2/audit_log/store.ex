defmodule ApiManagementConsoleV2.AuditLog.Store do
  @moduledoc false

  require Logger

  import ApiManagementConsoleV2.Debug, only: [log: 1]

  alias ApiManagementConsoleV2.Features

  @db_name :api_audit_db

  def append(entry) do
    # Use timestamp + random suffix as unique key
    key = "#{System.system_time(:millisecond)}_#{:rand.uniform(999_999)}"
    CubDB.put(@db_name, key, entry)

    log("[AuditStore] append — key=#{entry.key}, #{entry.old_state} → #{entry.new_state}")
    :ok
  end

  def list(offset, limit) do
    retention_days = Features.audit_retention_days()
    cutoff = cutoff_timestamp(retention_days)

    entries =
      CubDB.select(@db_name, reverse: true)
      |> Stream.filter(&within_retention?(&1, cutoff))
      |> Stream.drop(offset)
      |> Stream.take(limit)
      |> Stream.map(fn {_key, entry} -> entry end)
      |> Enum.to_list()

    # Recalculate total after filtering
    total =
      CubDB.select(@db_name)
      |> Stream.filter(&within_retention?(&1, cutoff))
      |> Enum.count()

    {entries, total}
  end

  defp cutoff_timestamp(:unlimited), do: nil

  defp cutoff_timestamp(days) when is_integer(days) do
    DateTime.add(DateTime.utc_now(), -days * 86400, :second)
  end

  defp within_retention?(_entry, nil), do: true

  defp within_retention?({_key, entry}, cutoff) do
    ts_str =
      cond do
        is_map(entry) -> entry["timestamp"] || entry[:timestamp] || entry.timestamp
        true -> ""
      end

    case DateTime.from_iso8601(to_string(ts_str)) do
      {:ok, ts} -> DateTime.compare(ts, cutoff) != :lt
      _ -> true
    end
  end

  def count do
    CubDB.size(@db_name)
  end
end
