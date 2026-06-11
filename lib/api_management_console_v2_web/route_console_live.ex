defmodule ApiManagementConsoleV2Web.RouteConsoleLive do
  @moduledoc """
  LiveView dashboard for managing route availability.

  Features:
    • Routes grouped by namespace
    • Health bar showing enabled vs disabled ratio
    • Sliding toggle switches (green ON / red OFF)
    • Immutable routes (protected) grayed out
    • Group toggle for bulk enable/disable
    • Works in LIVE and STATIC (dead render) modes
  """

  use Phoenix.LiveView

  require Logger

  alias ApiManagementConsoleV2.RoutePolicies

  @impl true
  def mount(_params, _session, socket) do
    Logger.debug("[ApiConsole] mount — connected?=#{connected?(socket)}, router=#{inspect(socket.router)}")

    RoutePolicies.start_link([])

    socket =
      socket
      |> assign(:grouped_routes, %{})
      |> assign(:stats, %{total: 0, enabled: 0, disabled: 0, disabled_ratio: 0.0})
      |> assign(:connected, connected?(socket))
      |> assign(:loading, %{})

    {:ok, load_dashboard(socket)}
  end

  @impl true
  def handle_event("toggle", %{"key" => key}, socket) do
    Logger.debug("[ApiConsole] toggle event — key=#{key}")

    route = find_route(socket.assigns.grouped_routes, key)

    if route && route.mutable do
      RoutePolicies.set_route_enabled(key, not route.enabled)
    end

    {:noreply, load_dashboard(socket)}
  end

  def handle_event("toggle_group", %{"group" => group}, socket) do
    Logger.debug("[ApiConsole] toggle_group event — group=#{group}")

    routes = Map.get(socket.assigns.grouped_routes, group, [])
    mutable = Enum.filter(routes, & &1.mutable)

    if mutable != [] do
      disable_all? = Enum.all?(mutable, & &1.enabled)
      RoutePolicies.set_group_enabled(socket.router, group, not disable_all?)
    end

    {:noreply, load_dashboard(socket)}
  end

  @impl true
  def handle_params(%{"toggle" => key}, uri, socket) do
    Logger.debug("[ApiConsole] toggle — key=#{key}")

    route = find_route(socket.assigns.grouped_routes, key)

    if route && route.mutable do
      RoutePolicies.set_route_enabled(key, not route.enabled)
    end

    clean_path = URI.parse(uri).path

    {:noreply,
     socket
     |> load_dashboard()
     |> push_patch(to: clean_path, replace: true)}
  end

  def handle_params(%{"toggle_group" => group}, uri, socket) do
    Logger.debug("[ApiConsole] toggle_group — group=#{group}")

    routes = Map.get(socket.assigns.grouped_routes, group, [])
    mutable = Enum.filter(routes, & &1.mutable)

    if mutable != [] do
      disable_all? = Enum.all?(mutable, & &1.enabled)
      RoutePolicies.set_group_enabled(socket.router, group, not disable_all?)
    end

    clean_path = URI.parse(uri).path

    {:noreply,
     socket
     |> load_dashboard()
     |> push_patch(to: clean_path, replace: true)}
  end

  def handle_params(_params, _uri, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <div class="console-root">
      <style>
        html, body { background: #fff !important; }
        .console-root { font-family: system-ui, sans-serif; max-width: 960px; margin: 2rem auto; padding: 0 1rem; background: #fff; }
        @media (prefers-color-scheme: dark) {
          html, body { background: #0f172a !important; }
          .console-root { background: #0f172a; color: #e2e8f0; }
          .console-card { background: #1e293b !important; border-color: #334155 !important; }
          .console-card-muted { background: #1e293b !important; border-color: #334155 !important; }
          .console-text-muted { color: #94a3b8 !important; }
          .console-group-card { background: #1e293b !important; border-color: #334155 !important; }
          .console-route-enabled { background: #052e16 !important; border-color: #166534 !important; }
          .console-route-disabled { background: #450a0a !important; border-color: #7f1d1d !important; }
          .console-route-immutable { background: #1e293b !important; border-color: #334155 !important; }
          .console-method-badge { background: #1e293b !important; color: #93c5fd !important; }
          .console-stat-label { color: #94a3b8 !important; }
          .console-powered-by { color: #475569 !important; }
          .console-progress-bg { background: #334155 !important; }
        }
        .console-card { background: #f9fafb; border: 1px solid #e5e7eb; border-radius: 24px; padding: 1.5rem; margin-bottom: 1.5rem; }
        .console-header-row { display: flex; flex-wrap: wrap; justify-content: space-between; align-items: flex-start; gap: 1rem; }
        .console-title { font-size: 1.5rem; font-weight: 600; margin: 0; }
        .console-subtitle { font-size: 0.875rem; color: #6b7280; margin-top: 0.25rem; }
        .console-stats { display: flex; flex-direction: column; align-items: flex-end; gap: 0.25rem; font-size: 0.875rem; }
        .console-stat-enabled { font-weight: 600; color: #166534; }
        .console-stat-disabled { font-weight: 600; color: #991b1b; }
        .console-stat-label { color: #6b7280; }
        .console-progress { width: 100%; height: 6px; border-radius: 3px; margin-top: 1rem; overflow: hidden; display: flex; }
        .console-progress-bg { background: #e5e7eb; flex: 1; border-radius: 3px; overflow: hidden; }
        .console-progress-fill { height: 100%; background: #166534; border-radius: 3px; transition: width 0.3s ease; }
        .console-progress-fill-danger { height: 100%; background: #991b1b; border-radius: 3px; transition: width 0.3s ease; }
        .console-group-card { background: #fff; border: 1px solid #e5e7eb; border-radius: 24px; padding: 1.25rem; margin-bottom: 1rem; }
        .console-group-header { display: flex; flex-wrap: wrap; justify-content: space-between; align-items: center; gap: 0.75rem; margin-bottom: 1rem; }
        .console-group-name { font-size: 1.1rem; font-weight: 600; margin: 0; }
        .console-group-count { font-size: 0.75rem; color: #6b7280; }
        .console-group-btn { border: 1px solid #d1d5db; border-radius: 999px; padding: 0.5rem 1rem; font-size: 0.75rem; font-weight: 600; text-transform: uppercase; letter-spacing: 0.05em; background: #fff; cursor: pointer; transition: all 0.15s; color: #374151; text-decoration: none; display: inline-block; }
        .console-group-btn:hover { border-color: #3b82f6; color: #2563eb; }
        .console-route-row { display: flex; align-items: center; justify-content: space-between; padding: 0.75rem; border-radius: 16px; border: 1px solid; margin-bottom: 0.5rem; transition: all 0.15s; }
        .console-route-enabled { border-color: #bbf7d0; background: #f0fdf4; }
        .console-route-disabled { border-color: #fecaca; background: #fef2f2; }
        .console-route-immutable { border-color: #e5e7eb; background: #f9fafb; opacity: 0.6; }
        .console-route-left { min-width: 0; flex: 1; }
        .console-route-meta { display: flex; align-items: center; gap: 0.5rem; }
        .console-method-badge { background: #e5e7eb; padding: 2px 8px; border-radius: 6px; font-size: 0.7rem; font-weight: 700; text-transform: uppercase; }
        .console-route-path { font-size: 0.875rem; font-weight: 500; margin: 0.25rem 0 0 0; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
        .console-route-plug { font-size: 0.75rem; color: #9ca3af; margin: 0; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
        .console-toggle { position: relative; width: 64px; height: 32px; border-radius: 16px; border: 1px solid; cursor: pointer; transition: all 0.3s; flex-shrink: 0; text-decoration: none; display: inline-block; padding: 0; }
        .console-toggle-on { background: #166534; border-color: #15803d; }
        .console-toggle-off { background: #991b1b; border-color: #b91c1c; }
        .console-toggle-immutable { background: #d1d5db; border-color: #d1d5db; cursor: not-allowed; }
        .console-toggle-knob { position: absolute; top: 2px; width: 26px; height: 26px; border-radius: 50%; background: #fff; box-shadow: 0 1px 3px rgba(0,0,0,0.2); transition: left 0.3s; }
        .console-toggle-knob-on { left: 34px; }
        .console-toggle-knob-off { left: 2px; }
        .console-powered-by { text-align: center; font-size: 0.75rem; color: #9ca3af; margin-top: 2rem; }
        .console-connection-badge { font-size: 0.65rem; font-weight: 600; padding: 2px 8px; border-radius: 4px; margin-left: 0.5rem; vertical-align: middle; }
        .console-connection-live { background: #166534; color: #fff; }
        .console-connection-static { background: #b45309; color: #fff; }
      </style>

      <div class="console-card">
        <div class="console-header-row">
          <div>
            <h1 class="console-title">
              API Management Console
              <span class={"console-connection-badge " <> if(@connected, do: "console-connection-live", else: "console-connection-static")}>
                <%= if @connected, do: "LIVE", else: "STATIC" %>
              </span>
            </h1>
            <p class="console-subtitle">Control route availability in real time.</p>
          </div>
          <div class="console-stats">
            <div>
              <span class="console-stat-enabled"><%= @stats.enabled %> enabled</span>
              <%= if @stats.disabled > 0 do %>
                / <span class="console-stat-disabled"><%= @stats.disabled %> disabled</span>
              <% end %>
            </div>
            <span class="console-stat-label"><%= @stats.total %> total mutable routes</span>
          </div>
        </div>

        <%= if @stats.total > 0 do %>
          <div class="console-progress">
            <div class="console-progress-bg">
              <div class="console-progress-fill" style={"width:#{@stats.enabled / @stats.total * 100}%"} />
            </div>
          </div>
        <% end %>

        <%= if not @connected do %>
          <p style="margin-top:1rem; font-size:0.8rem; color:#b45309; background:#fef3c7; padding:0.5rem 0.75rem; border-radius:6px;">
            💡 Toggles work but cause a page reload. For instant toggles, ensure your app loads LiveView&rsquo;s JavaScript client.
          </p>
        <% end %>
      </div>

      <%= for {group, routes} <- @grouped_routes do %>
        <% mutable_count = Enum.count(routes, & &1.mutable) %>
        <div class="console-group-card">
          <div class="console-group-header">
            <div>
              <h2 class="console-group-name"><%= group %></h2>
              <span class="console-group-count"><%= Enum.count(routes) %> routes</span>
            </div>
            <%= if mutable_count > 0 do %>
              <button phx-click="toggle_group" phx-value-group={group} class="console-group-btn">
                Toggle Group
              </button>
            <% end %>
          </div>

          <%= for route <- routes do %>
            <div class={
              "console-route-row " <>
              cond do
                not route.mutable -> "console-route-immutable"
                route.enabled -> "console-route-enabled"
                true -> "console-route-disabled"
              end
            }>
              <div class="console-route-left">
                <div class="console-route-meta">
                  <span class="console-method-badge"><%= route.method %></span>
                  <span class="console-stat-label"><%= route.controller %>.<%= route.action %></span>
                </div>
                <p class="console-route-path"><%= route.path %></p>
              </div>

              <button
                :if={route.mutable}
                phx-click="toggle"
                phx-value-key={route.key}
                class={"console-toggle " <> if(route.enabled, do: "console-toggle-on", else: "console-toggle-off")}
              >
                <span class={"console-toggle-knob " <> if(route.enabled, do: "console-toggle-knob-on", else: "console-toggle-knob-off")} />
              </button>
              <span :if={not route.mutable} class="console-toggle console-toggle-immutable">
                <span class="console-toggle-knob console-toggle-knob-on" />
              </span>
            </div>
          <% end %>
        </div>
      <% end %>

      <p class="console-powered-by">Powered by API Management Console</p>
    </div>
    """
  end

  # --- helpers ---

  defp load_dashboard(socket) do
    router = socket.router

    grouped_routes =
      try do
        RoutePolicies.list_grouped_routes(router)
      rescue
        _ -> %{}
      end

    stats = compute_stats(grouped_routes)

    Logger.debug("[ApiConsole] load — groups=#{map_size(grouped_routes)}, total=#{stats.total}, enabled=#{stats.enabled}, disabled=#{stats.disabled}")

    socket
    |> assign(:grouped_routes, grouped_routes)
    |> assign(:stats, stats)
  end

  defp compute_stats(grouped_routes) do
    mutable =
      grouped_routes
      |> Map.values()
      |> List.flatten()
      |> Enum.filter(& &1.mutable)

    total = Enum.count(mutable)
    enabled = Enum.count(mutable, & &1.enabled)
    disabled = total - enabled
    ratio = if total > 0, do: disabled / total, else: 0.0

    %{total: total, enabled: enabled, disabled: disabled, disabled_ratio: ratio}
  end

  defp find_route(grouped_routes, key) do
    grouped_routes
    |> Map.values()
    |> List.flatten()
    |> Enum.find(&(&1.key == key))
  end
end
