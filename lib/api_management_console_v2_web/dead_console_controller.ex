defmodule ApiManagementConsoleV2Web.DeadConsoleController do
  @moduledoc """
  Handles POST actions from the dead-render (non-LiveView) console.

  When LiveView JS is not available, forms use `method="post"` and submit
  to this controller. Each action is identified by a hidden field in the form
  body. After processing, the controller redirects back to the console page.

  Handles: add_account, delete_account, reset_all
  """

  use Phoenix.Controller, formats: [:html]

  alias ApiManagementConsoleV2.{Accounts, AuditLog, RoutePolicies}

  def action(conn, _opts) do
    # Handle POST actions from dead-render forms
    # Each action is identified by a hidden field in the form
    params = conn.params

    conn =
      cond do
        params["add_account"] == "true" ->
          handle_add_account(conn, params)

        params["delete_account"] ->
          handle_delete_account(conn, params)

        params["reset_all"] == "true" ->
          handle_reset_all(conn)

        true ->
          conn
      end

    # Redirect back to console (strip params)
    redirect(conn, to: conn.request_path)
  end

  defp handle_add_account(conn, params) do
    username = get_session(conn, :api_console_user)
    actor = if username, do: username["username"], else: "unknown"

    if Accounts.can_create?() do
      role = Accounts.parse_role(params["role"] || "viewer")

      case Accounts.create(params["username"], params["password"], role) do
        :ok ->
          AuditLog.append(actor, "add_account", params["username"], nil, nil)

        {:error, _} ->
          :ok
      end
    end

    conn
  end

  defp handle_delete_account(conn, params) do
    username = get_session(conn, :api_console_user)
    actor = if username, do: username["username"], else: "unknown"

    Accounts.delete(params["delete_account"])
    AuditLog.append(actor, "delete_account", params["delete_account"], nil, nil)

    conn
  end

  defp handle_reset_all(conn) do
    username = get_session(conn, :api_console_user)
    actor = if username, do: username["username"], else: "unknown"

    RoutePolicies.reset_all()
    AuditLog.append(actor, "reset_all", "*", nil, nil)

    conn
  end
end
