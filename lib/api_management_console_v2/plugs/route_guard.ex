defmodule ApiManagementConsoleV2.Plugs.RouteGuard do
  @moduledoc """
  A Plug that blocks requests to disabled routes with a `403 Forbidden`.

  Checks `ApiManagementConsoleV2.RoutePolicies` for the current request.
  Immutable routes and routes not found in the policy store pass through.
  Only explicitly disabled mutable routes are blocked.

  ## Usage

  Automatic via `use ApiManagementConsoleV2.Router` (the `:route_guard` pipeline).

  Or manually inside any pipeline:

      pipeline :api do
        plug ApiManagementConsoleV2.Plugs.RouteGuard
      end
  """

  @behaviour Plug

  import Plug.Conn

  alias ApiManagementConsoleV2.RoutePolicies

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    router = :persistent_term.get({:api_management_console, :phoenix_router}, nil)

    # Never block the console itself — always allow
    console_paths = :persistent_term.get({:api_management_console, :console_paths}, [])
    is_console = Enum.any?(console_paths, fn p -> String.starts_with?(conn.request_path, p) end)

    allowed = is_console or (router && RoutePolicies.request_allowed?(router, conn.method, conn.request_path))

    if allowed do
      conn
    else
      conn
      |> send_resp(403, "Route disabled")
      |> halt()
    end
  end
end
