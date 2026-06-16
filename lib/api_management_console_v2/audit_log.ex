defmodule ApiManagementConsoleV2.AuditLog do
  @moduledoc """
  Action log for every route toggle — who did what, when, old→new state.

  Storage is swappable via `AuditLog.Store`. Currently CubDB-backed.
  Same pattern as `RoutePolicies.Store` — will support PostgreSQL later.

  ## Usage

      AuditLog.append("admin", "toggle", "get|/api/users", true, false)
      AuditLog.list(offset: 0, limit: 10)
  """

  alias ApiManagementConsoleV2.AuditLog.Store

  @doc "Append a log entry. Returns :ok."
  def append(who, action, key, old_state, new_state) do
    entry = %{
      who: who,
      action: action,
      key: key,
      old_state: old_state,
      new_state: new_state,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    Store.append(entry)
  end

  @doc "List entries with pagination. Returns {entries, total_count}."
  def list(opts \\ []) do
    offset = Keyword.get(opts, :offset, 0)
    limit = Keyword.get(opts, :limit, 10)

    Store.list(offset, limit)
  end

  @doc "Total number of audit entries."
  def count, do: Store.count()
end
