defmodule ApiManagementConsoleV2Web.Plugs.RequireAdmin do
  @moduledoc """
  A Plug that enforces HTTP Basic Authentication.

  Credentials are read from environment variables:

    - `API_CONSOLE_ADMIN_USERNAME` (default: `"admin"`)
    - `API_CONSOLE_ADMIN_PASSWORD` (default: `"admin123"`)

  If the request has no valid Authorization header, the plug returns
  a 401 response with a `WWW-Authenticate` header, prompting the
  browser to show its native login dialog.
  """

  @behaviour Plug

  import Plug.Conn

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    username = System.get_env("API_CONSOLE_ADMIN_USERNAME", "admin")
    password = System.get_env("API_CONSOLE_ADMIN_PASSWORD", "admin123")

    case get_req_header(conn, "authorization") do
      ["Basic " <> encoded] ->
        case Base.decode64(encoded) do
          {:ok, ^username <> ":" <> ^password} ->
            conn

          _ ->
            auth_fail(conn)
        end

      _ ->
        auth_fail(conn)
    end
  end

  defp auth_fail(conn) do
    conn
    |> put_resp_header("www-authenticate", ~s|Basic realm="API Console"|)
    |> send_resp(401, "Unauthorized")
    |> halt()
  end
end
