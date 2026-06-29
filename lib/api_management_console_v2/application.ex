defmodule ApiManagementConsoleV2.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      %{id: :cubdb_policies, start: {CubDB, :start_link, [[name: :api_policies_db, data_dir: data_dir("api_policies")]]}},
      %{id: :cubdb_audit, start: {CubDB, :start_link, [[name: :api_audit_db, data_dir: data_dir("api_audit")]]}},
      %{id: :cubdb_accounts, start: {CubDB, :start_link, [[name: :api_accounts_db, data_dir: data_dir("api_accounts")]]}}
    ]

    opts = [strategy: :one_for_one, name: ApiManagementConsoleV2.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp data_dir(suffix) do
    dir = Application.get_env(:api_management_console, :storage_dir, "api-console-data")
    Path.join(dir, suffix)
  end
end
