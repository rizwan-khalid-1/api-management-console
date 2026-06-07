defmodule ApiManagementConsoleV2.Router do
  @moduledoc """
  Provides the `api_console/1` macro to mount console routes into a Phoenix router.

  The macro is transparent — it only defines routes under the given path.
  You control authentication, pipelines, and scoping entirely.

  ## Using the macro

      scope "/" do
        pipe_through [:browser, :my_auth]
        api_console "/admin/apis"
      end

  ## Manually (no macro)

  See the README for a manual route listing if you prefer full control.
  """

  @doc """
  Mounts the API console dashboard routes under the given path.

  All routes are scoped under `path`. No pipeline or auth is forced —
  the caller's surrounding `pipe_through` applies exactly as-is.
  """
  defmacro api_console(path) do
    quote bind_quoted: [path: path] do
      scope path, alias: false, as: false do
        get "/", ApiManagementConsoleV2.ConsoleController, :index
      end
    end
  end
end
