defmodule ApiManagementConsoleV2Web.LoginController do
  @moduledoc false

  use Phoenix.Controller, formats: [:html]

  alias ApiManagementConsoleV2.{Accounts, Branding}

  def index(conn, _params) do
    Accounts.ensure_admin_exists()

    conn
    |> put_layout(false)
    |> render_login(nil, "")
  end

  def create(conn, %{"username" => username, "password" => password}) do
    Accounts.ensure_admin_exists()

    case Accounts.authenticate(username, password) do
      {:ok, role} ->
        return_to = get_session(conn, :return_to) || console_path(conn)

        conn
        |> put_session(:api_console_user, %{"username" => username, "role" => Atom.to_string(role)})
        |> redirect(to: return_to)

      {:error, _} ->
        conn
        |> put_layout(false)
        |> render_login("Invalid username or password", username)
    end
  end

  defp template_path do
    Path.join(:code.priv_dir(:api_management_console), "templates/login.html.eex")
  end

  defp render_login(conn, error, username) do
    assigns = %{
      app_name: Branding.app_name(),
      csrf_token: Plug.CSRFProtection.get_csrf_token(),
      error: error,
      username: username
    }

    html = EEx.eval_file(template_path(), assigns: assigns)
    html(conn, html)
  end

  defp console_path(conn) do
    conn.request_path
    |> String.replace(~r{/[^/]+$}, "")
  end
end
