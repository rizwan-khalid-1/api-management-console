defmodule ApiManagementConsoleV2 do
  @moduledoc """
  A simple library to discover and list routes from a Phoenix application's router.

  ## Installation

  Add to your `mix.exs`:

      {:api_management_console_v2, path: "/path/to/api_management_console_v2"}

  ## Usage

      iex> ApiManagementConsoleV2.list_routes(MyAppWeb.Router)
      [%{path: "/", method: "GET", controller: MyAppWeb.PageController, action: :index}, ...]
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
      controller: route.plug |> Module.split() |> List.last(),
      action: route.plug_opts,
      plug: route.plug,
      plug_opts: route.plug_opts,
      helper: route.helper
    }
  end
end
