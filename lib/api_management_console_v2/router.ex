defmodule ApiManagementConsoleV2.Router do
  @moduledoc """
  Provides the `api_console/1` macro to mount console routes into a Phoenix router.

  The macro is transparent — it defines login routes and protected dashboard routes
  under the given path with session-based authentication. The consumer controls the
  outer pipeline and scoping.

  ## Using the macro

      # In your router module — `use` defines the auth pipeline:
      use ApiManagementConsoleV2.Router

      scope "/" do
        pipe_through [:browser]
        api_console "/admin/apis"
      end

  ## Manual setup (no macro)

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

  Routes are wrapped with the `:api_console_auth` pipeline (session-based auth).
  Credentials are managed via the login page (default: admin / admin123).
  """
  defmacro api_console(path) do
    quote bind_quoted: [path: path] do
      # Store the console path so it's automatically protected from being disabled
      ApiManagementConsoleV2.ConsolePaths.add(path)

      # Login page — no auth required (uses controller for session-based auth)
      scope path, alias: false, as: false do
        get "/login", ApiManagementConsoleV2Web.LoginController, :index
        post "/login", ApiManagementConsoleV2Web.LoginController, :create
      end

      # Protected console routes
      scope path, alias: false, as: false do
        import Phoenix.LiveView.Router, only: [live: 3]
        pipe_through [:api_console_auth]
        get "/logout", ApiManagementConsoleV2Web.Plugs.Logout, []
        get "/audit.csv", ApiManagementConsoleV2Web.Plugs.AuditDownload, []
        live "/", ApiManagementConsoleV2Web.RouteConsoleLive, :index
      end
    end
  end
end
