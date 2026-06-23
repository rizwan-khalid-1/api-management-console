defmodule ApiManagementConsoleV2Web.Plugs.Logout do
  @moduledoc false

  @behaviour Plug

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    conn
    |> clear_session()
    |> Phoenix.Controller.redirect(to: login_path(conn))
    |> halt()
  end

  defp login_path(conn) do
    String.replace(conn.request_path, ~r{/[^/]+$}, "/login")
  end
end
