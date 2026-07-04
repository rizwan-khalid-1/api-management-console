defmodule ApiManagementConsoleV2Web.Plugs.RequireAdmin do
  @moduledoc """
  Ensures the user is authenticated before accessing console routes.

  Checks `Plug.Conn.get_session/2` for `:api_console_user`.
  If not authenticated, redirects to the login page.
  If authenticated, assigns `:api_console_user` to the conn for downstream use.

  ## Session key

      :api_console_user → %{username: "john", role: :admin}
  """

  @behaviour Plug

  import Plug.Conn

  alias ApiManagementConsoleV2.Accounts

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    case get_session(conn, :api_console_user) do
      %{"username" => username, "role" => role} ->
        user = %{username: username, role: Accounts.parse_role(role)}
        assign(conn, :api_console_user, user)

      nil ->
        conn
        |> put_session(:return_to, conn.request_path)
        |> Phoenix.Controller.redirect(to: login_path(conn))
        |> halt()
    end
  end

  defp login_path(conn) do
    conn.request_path <> "/login"
  end
end
