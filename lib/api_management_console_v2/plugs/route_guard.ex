defmodule ApiManagementConsoleV2.Plugs.RouteGuard do
  @moduledoc """
  A Plug that blocks requests to disabled routes with a `403 Forbidden`.

  Checks `ApiManagementConsoleV2.RoutePolicies` for the current
  request's full path (METHOD + request_path joined). If the route is
  explicitly disabled, the request is halted with 403.

  Routes not found in the policy store default to **enabled**.

  ## Usage

  Add to the pipeline(s) you want to protect:

      pipeline :api do
        plug ApiManagementConsoleV2.Plugs.RouteGuard
      end

      pipeline :browser do
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
    full_path = "#{conn.method} #{conn.request_path}"

    case Process.whereis(RoutePolicies) do
      nil ->
        # Policy store not started yet — pass through
        conn

      _pid ->
        if RoutePolicies.enabled?(full_path) do
          conn
        else
          conn
          |> send_resp(403, "Route disabled — #{full_path}")
          |> halt()
        end
    end
  end
end
