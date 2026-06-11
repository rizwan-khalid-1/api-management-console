defmodule ApiManagementConsoleV2.RoutePolicies do
  @moduledoc """
  Route policy management for enabling/disabling endpoints.

  Backed by DETS for persistence. Routes are keyed as `"method|path"`
  (e.g. `"get|/api/users"`). Some routes are immutable (protected) and
  cannot be toggled — configured via `:api_management_console, :protected_routes`.

  Supports string prefixes/suffixes and regex patterns (matched against path and controller):

      config :api_management_console,
        protected_routes: ["/dev/dashboard", ~r{HealthController}]
  """

  use GenServer

  require Logger

  alias ApiManagementConsoleV2.RoutePolicies.Store

  # --- Public API ---

  @doc "Returns routes grouped by namespace, with enabled state and mutable flag."
  def list_grouped_routes(router) do
    stored = Map.new(Store.all())

    router.__routes__()
    |> Enum.map(&build_route_entry(&1, stored))
    |> Enum.reject(&is_nil(&1))
    |> Enum.sort_by(&{&1.group, &1.path, &1.method})
    |> Enum.group_by(& &1.group)
  end

  @doc "Returns all routes as a flat list."
  def list_all_routes(router) do
    router
    |> list_grouped_routes()
    |> Map.values()
    |> List.flatten()
  end

  @doc "Toggle a single route by key."
  def set_route_enabled(route_key, enabled) when is_binary(route_key) and is_boolean(enabled) do
    Logger.debug("[ApiPolicies] set_route_enabled — key=#{route_key}, enabled=#{enabled}")
    Store.put(route_key, enabled)
  end

  @doc "Toggle all mutable routes in a group."
  def set_group_enabled(router, group, enabled) do
    router
    |> list_grouped_routes()
    |> Map.get(group, [])
    |> Enum.filter(& &1.mutable)
    |> Enum.map(&{&1.key, enabled})
    |> Store.bulk_put()
  end

  @doc "Check if a route is enabled by key."
  def enabled?(key), do: Store.enabled?(key)

  @doc "Check if a request (method + path) is allowed."
  def request_allowed?(router, method, path) do
    routes = list_all_routes(router)
    normalized = normalize_method(method)

    result = case find_matching_route(routes, normalized, path) do
      {:ok, %{mutable: true, key: key}} -> {:mutable, key, enabled?(key)}
      {:ok, _immutable} -> {:immutable, nil, true}
      :error -> {:not_found, nil, true}
    end

    Logger.debug("[ApiPolicies] request_allowed? — #{method} #{path} -> #{inspect(result)}")

    elem(result, 2)
  end

  # --- GenServer ---

  @doc false
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    _ = File.mkdir_p!("tmp")
    {:ok, nil}
  end

  # --- Private ---

  defp build_route_entry(route, stored) do
    if is_nil(route.verb) or not is_binary(route.path) do
      nil
    else
      key = route_key(route.verb, route.path)
      mutable = mutable_route?(route)

      %{
        key: key,
        method: route.verb |> to_string() |> String.upcase(),
        path: route.path,
        controller: format_controller(route.plug),
        action: format_action(route.plug_opts),
        group: group_name(route),
        mutable: mutable,
        enabled: if(mutable, do: Map.get(stored, key, true), else: true),
        plug: route.plug
      }
    end
  end

  defp route_key(verb, path) do
    "#{normalize_method(verb)}|#{path}"
  end

  defp normalize_method(method) when is_atom(method),
    do: method |> Atom.to_string() |> String.downcase()

  defp normalize_method(method) when is_binary(method), do: String.downcase(method)

  defp mutable_route?(route) do
    user_protected = Application.get_env(:api_management_console, :protected_routes, [])
    console_paths = :persistent_term.get({:api_management_console, :console_paths}, [])
    immutable_prefixes = user_protected ++ console_paths

    is_immutable = Enum.any?(immutable_prefixes, fn prefix ->
      cond do
        is_binary(prefix) ->
          String.starts_with?(route.path, prefix) or String.ends_with?(route.path, prefix)
        is_struct(prefix, Regex) ->
          Regex.match?(prefix, route.path) or Regex.match?(prefix, inspect(route.plug))
        true -> false
      end
    end)

    Logger.debug("[ApiPolicies] mutable? — path=#{route.path}, immutable_prefixes=#{inspect(immutable_prefixes)}, is_immutable=#{is_immutable}")

    not is_immutable
  end

  defp group_name(route) do
    route.plug
    |> Module.split()
    |> case do
      [name] -> name
      [namespace | _] -> namespace
      _ -> "Other"
    end
  end

  defp format_controller(plug) when is_atom(plug),
    do: plug |> Module.split() |> List.last()

  defp format_controller(_plug), do: "unknown"

  defp format_action(plug_opts) when is_atom(plug_opts), do: plug_opts
  defp format_action(plug_opts) when is_binary(plug_opts), do: plug_opts
  defp format_action({key, _val}) when is_atom(key), do: key
  defp format_action(_plug_opts), do: :unknown

  defp find_matching_route(routes, method, path) do
    Enum.find(routes, fn r ->
      normalized = normalize_method(r.method) == method
      normalized and route_path_match?(r.path, path)
    end)
    |> case do
      nil -> :error
      route -> {:ok, route}
    end
  end

  defp route_path_match?(route_path, request_path) when route_path == request_path, do: true

  defp route_path_match?(route_path, request_path) do
    route_segments = String.split(route_path, "/", trim: true)
    request_segments = String.split(request_path, "/", trim: true)

    if length(route_segments) == length(request_segments) do
      Enum.zip(route_segments, request_segments)
      |> Enum.all?(fn {route_part, request_part} ->
        String.starts_with?(route_part, ":") or route_part == request_part
      end)
    else
      false
    end
  end
end
