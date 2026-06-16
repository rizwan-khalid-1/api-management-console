defmodule ApiManagementConsoleV2.Router do
  @moduledoc """
  Provides the `api_console/1` macro to mount console routes into a Phoenix router.

  The macro is transparent — it only defines routes under the given path
  with Basic Auth protection. You control the outer pipeline and scoping.

  ## Using the macro

      # In your router module — `use` defines the auth pipeline:
      use ApiManagementConsoleV2.Router

      scope "/" do
        pipe_through [:browser]
        api_console "/admin/apis"
      end

  ## Manually (no macro)

  See the README for a manual route listing if you prefer full control.
  """

  @doc """
  Sets up the API console in the caller's router module.

  Defines the `:api_console_auth` pipeline (Basic Auth via `RequireAdmin`)
  and imports the `api_console/1` macro.
  """
  defmacro __using__(_opts) do
    quote do
      :persistent_term.put({:api_management_console, :phoenix_router}, __MODULE__)
      ApiManagementConsoleV2.ConsolePaths.init()
      import ApiManagementConsoleV2.Router, only: [api_console: 1]

      pipeline :route_guard do
        plug ApiManagementConsoleV2.Plugs.RouteGuard
      end

      pipeline :api_console_auth do
        plug ApiManagementConsoleV2Web.Plugs.RequireAdmin
      end
    end
  end

  @doc """
  Mounts the API console LiveView dashboard under the given path.

  Routes are wrapped with the `:api_console_auth` pipeline (HTTP Basic Auth).
  Credentials are read from `API_CONSOLE_ADMIN_USERNAME` / `API_CONSOLE_ADMIN_PASSWORD`.
  """
  defmacro api_console(path) do
    quote bind_quoted: [path: path] do
      # Store the console path so it's automatically protected from being disabled
      ApiManagementConsoleV2.ConsolePaths.add(path)

      scope path, alias: false, as: false do
        import Phoenix.LiveView.Router, only: [live: 3]
        pipe_through [:api_console_auth]
        get "/audit.csv", ApiManagementConsoleV2Web.Plugs.AuditDownload, []
        live "/", ApiManagementConsoleV2Web.RouteConsoleLive, :index
      end
    end
  end
end
