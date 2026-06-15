defmodule ApiManagementConsoleV2Web.Plugs.AuditDownload do
  @moduledoc false

  @behaviour Plug

  import Plug.Conn

  alias ApiManagementConsoleV2.AuditLog

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    {entries, _} = AuditLog.list(offset: 0, limit: 10_000)

    csv = entries_to_csv(entries)

    conn
    |> put_resp_content_type("text/csv")
    |> put_resp_header("content-disposition", "attachment; filename=api_audit_log.csv")
    |> send_resp(200, csv)
    |> halt()
  end

  defp entries_to_csv(entries) do
    header = "timestamp,action,route_key,old_state,new_state\n"

    rows =
      Enum.map(entries, fn e ->
        "#{e.timestamp},#{e.action},#{e.key},#{e.old_state},#{e.new_state}"
      end)

    header <> Enum.join(rows, "\n")
  end
end
