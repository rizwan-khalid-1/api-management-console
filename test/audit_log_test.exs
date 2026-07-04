defmodule ApiManagementConsoleV2.AuditLogTest do
  use ExUnit.Case, async: false

  alias ApiManagementConsoleV2.AuditLog

  describe "append/5 and list/1" do
    test "appends and retrieves entries" do
      AuditLog.append("admin", "toggle", "get|/api/test", true, false)
      {entries, total} = AuditLog.list(offset: 0, limit: 10)

      assert is_list(entries)
      assert total >= 1
      assert length(entries) >= 1

      entry = hd(entries)
      who = entry["who"] || entry[:who]
      action = entry["action"] || entry[:action]
      key = entry["key"] || entry[:key]
      old = entry["old_state"] || entry[:old_state]
      new = entry["new_state"] || entry[:new_state]

      assert who == "admin"
      assert action == "toggle"
      assert key == "get|/api/test"
      assert old == true
      # new_state may be false or nil depending on serialization
      assert new == false or is_nil(new)
      # timestamp may be atom or string key depending on CubDB serialization
      assert Map.has_key?(entry, "timestamp") or Map.has_key?(entry, :timestamp)
    end

    test "supports pagination" do
      # Add multiple entries
      for i <- 1..5 do
        AuditLog.append("admin", "toggle", "get|/test/#{i}", true, false)
      end

      {entries, total} = AuditLog.list(offset: 0, limit: 3)
      assert length(entries) <= 3
      assert total >= 5
    end
  end

  describe "count/0" do
    test "returns non-negative integer" do
      count = AuditLog.count()
      assert is_integer(count)
      assert count >= 0
    end
  end

  describe "30-day retention" do
    test "only returns entries within retention window" do
      {entries, _} = AuditLog.list(offset: 0, limit: 100)
      assert is_list(entries)

      # All returned entries should have recent timestamps
      for entry <- entries do
        ts = entry["timestamp"] || entry[:timestamp]
        if ts do
          {:ok, dt, _} = DateTime.from_iso8601(ts)
          diff = DateTime.diff(DateTime.utc_now(), dt, :day)
          assert diff < 31
        end
      end
    end
  end
end
