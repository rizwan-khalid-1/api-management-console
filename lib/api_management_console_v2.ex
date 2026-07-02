defmodule ApiManagementConsoleV2 do
  @moduledoc """
  A Phoenix LiveView library for real-time API route management.

  Discover routes, toggle them on/off, enforce via a Plug, with RBAC,
  audit logs, and a licensing model (Free/PRO).

  ## Installation

  Add to your `mix.exs`:

      {:api_management_console, github: "rizwankhalid/api_management_console"}

  ## Usage

      use ApiManagementConsoleV2.Router

      scope "/" do
        pipe_through [:browser, :route_guard]
        api_console "/admin/api-console"
      end
  """

  @doc """
  Returns all routes defined in the given Phoenix router module.

  ## Example

      routes = ApiManagementConsoleV2.list_routes(MyAppWeb.Router)
      Enum.each(routes, &IO.inspect/1)

  """
  def list_routes(router_module) when is_atom(router_module) do
    Code.ensure_loaded!(router_module)

    if function_exported?(router_module, :__routes__, 0) do
      router_module.__routes__()
      |> Enum.map(&route_to_map/1)
    else
      []
    end
  end

  @doc """
  Returns route paths as formatted strings: `"GET /api/users → MyApp.UserController.index"`

  ## Example

      iex> ApiManagementConsoleV2.list_routes_as_strings(MyAppWeb.Router)
      ["GET / → PageController.index", ...]

  """
  def list_routes_as_strings(router_module) do
    router_module
    |> list_routes()
    |> Enum.map(fn r ->
      "#{r.method} #{r.path} → #{r.controller}.#{r.action}"
    end)
  end

  # Private helpers

  defp route_to_map(route) do
    %{
      path: route.path,
      method: route.verb |> to_string() |> String.upcase(),
      controller: format_controller(route.plug),
      action: format_action(route.plug_opts),
      plug: route.plug,
      plug_opts: route.plug_opts,
      helper: route.helper
    }
  end

  defp format_controller(plug) when is_atom(plug) do
    plug |> Module.split() |> List.last()
  end

  defp format_controller(_plug), do: "unknown"

  defp format_action(plug_opts) when is_atom(plug_opts), do: plug_opts
  defp format_action(plug_opts) when is_binary(plug_opts), do: plug_opts
  defp format_action({key, _val}) when is_atom(key), do: key
  defp format_action(_plug_opts), do: :unknown
end
