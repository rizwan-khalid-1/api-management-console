defmodule ApiManagementConsoleV2Web.RouteConsoleLive do
  @moduledoc """
  LiveView dashboard for managing route availability.

  Features:
    • Routes grouped by namespace (toggleable to flat view)
    • Health bar + enabled/disabled counts
    • Search & filter by path, method, or controller
    • Sliding toggle switches + group toggles
    • Bulk select with enable/disable all
    • Expandable audit log with pagination
    • Immutable routes grayed out
    • Works in LIVE and STATIC modes
  """

  use Phoenix.LiveView

  require Logger

  alias ApiManagementConsoleV2.{AuditLog, Branding, HiddenRoutes, RoutePolicies}

  @page_size 10

  @impl true
  def mount(_params, _session, socket) do
    Logger.debug("[ApiConsole] mount — connected?=#{connected?(socket)}, router=#{inspect(socket.router)}")

    RoutePolicies.start_link([])

    socket =
      socket
      |> assign(:grouped_routes, %{})
      |> assign(:stats, %{total: 0, enabled: 0, disabled: 0, disabled_ratio: 0.0})
      |> assign(:connected, connected?(socket))
      |> assign(:search_query, "")
      |> assign(:group_by_controller, true)
      |> assign(:selected_keys, MapSet.new())
      |> assign(:audit_entries, [])
      |> assign(:audit_offset, 0)
      |> assign(:audit_total, 0)
      |> assign(:audit_expanded, false)
      |> assign(:console_path, "/admin/api-console")
      |> assign(:show_confirm_reset, false)
      |> assign(:show_hidden_modal, false)
      |> assign(:hidden_routes_list, [])

    {:ok, load_dashboard(socket)}
  end

  # --- Single toggle ---

  @impl true
  def handle_event("toggle", %{"key" => key}, socket) do
    route = find_route(socket.assigns.grouped_routes, key)

    if route && route.mutable do
      new_state = not route.enabled
      RoutePolicies.set_route_enabled(key, new_state)
      AuditLog.append("admin", "toggle", key, route.enabled, new_state)
    end

    {:noreply, load_dashboard(socket) |> clear_selection()}
  end

  # --- Group toggle ---

  def handle_event("toggle_group", %{"group" => group}, socket) do
    routes = Map.get(socket.assigns.grouped_routes, group, [])
    mutable = Enum.filter(routes, & &1.mutable)

    if mutable != [] do
      disable_all? = Enum.all?(mutable, & &1.enabled)
      new_state = not disable_all?
      RoutePolicies.set_group_enabled(socket.router, group, new_state)

      Enum.each(mutable, fn r ->
        AuditLog.append("admin", "toggle_group", "#{group}/*", r.enabled, new_state)
      end)
    end

    {:noreply, load_dashboard(socket) |> clear_selection()}
  end

  # --- Search ---

  def handle_event("search", %{"value" => query}, socket) do
    {:noreply, socket |> assign(:search_query, query) |> apply_search()}
  end

  # --- Bulk selection ---

  def handle_event("select", %{"key" => key}, socket) do
    selected =
      if MapSet.member?(socket.assigns.selected_keys, key) do
        MapSet.delete(socket.assigns.selected_keys, key)
      else
        MapSet.put(socket.assigns.selected_keys, key)
      end

    {:noreply, assign(socket, :selected_keys, selected)}
  end

  def handle_event("select_all", %{"group" => group}, socket) do
    routes = Map.get(socket.assigns.filtered_routes || socket.assigns.grouped_routes, group, [])
    keys = Enum.filter(routes, & &1.mutable) |> Enum.map(& &1.key)
    {:noreply, assign(socket, :selected_keys, MapSet.union(socket.assigns.selected_keys, MapSet.new(keys)))}
  end

  def handle_event("select_all", _params, socket) do
    all_keys = mutable_keys(socket.assigns.filtered_routes || socket.assigns.grouped_routes)
    {:noreply, assign(socket, :selected_keys, MapSet.new(all_keys))}
  end

  def handle_event("deselect_group", %{"group" => group}, socket) do
    routes = Map.get(socket.assigns.filtered_routes || socket.assigns.grouped_routes, group, [])
    keys = Enum.filter(routes, & &1.mutable) |> Enum.map(& &1.key) |> MapSet.new()
    {:noreply, assign(socket, :selected_keys, MapSet.difference(socket.assigns.selected_keys, keys))}
  end

  def handle_event("deselect_all", _params, socket) do
    {:noreply, assign(socket, :selected_keys, MapSet.new())}
  end

  def handle_event("bulk_enable", _params, socket) do
    updates = Enum.map(socket.assigns.selected_keys, &{&1, true})
    RoutePolicies.Store.bulk_put(updates)

    Enum.each(socket.assigns.selected_keys, fn key ->
      AuditLog.append("admin", "bulk_enable", key, nil, true)
    end)

    {:noreply, load_dashboard(socket) |> clear_selection()}
  end

  def handle_event("bulk_disable", _params, socket) do
    updates = Enum.map(socket.assigns.selected_keys, &{&1, false})
    RoutePolicies.Store.bulk_put(updates)

    Enum.each(socket.assigns.selected_keys, fn key ->
      AuditLog.append("admin", "bulk_disable", key, nil, false)
    end)

    {:noreply, load_dashboard(socket) |> clear_selection()}
  end

  # --- Grouping toggle ---

  def handle_event("toggle_grouping", _params, socket) do
    {:noreply, socket |> assign(:group_by_controller, not socket.assigns.group_by_controller) |> apply_search()}
  end

  # --- Audit log ---

  def handle_event("toggle_audit", _params, socket) do
    if socket.assigns.audit_expanded do
      {:noreply, assign(socket, :audit_expanded, false)}
    else
      {entries, total} = AuditLog.list(offset: 0, limit: @page_size)
      {:noreply, assign(socket, audit_expanded: true, audit_entries: entries, audit_offset: @page_size, audit_total: total)}
    end
  end

  def handle_event("load_more_audit", _params, socket) do
    {entries, total} = AuditLog.list(offset: socket.assigns.audit_offset, limit: @page_size)
    all = socket.assigns.audit_entries ++ entries
    {:noreply, assign(socket, audit_entries: all, audit_offset: socket.assigns.audit_offset + @page_size, audit_total: total)}
  end

  # --- Hide routes ---

  def handle_event("hide_selected", _params, socket) do
    keys = MapSet.to_list(socket.assigns.selected_keys)

    if keys != [] do
      HiddenRoutes.hide(keys)
      routes = socket.assigns.grouped_routes |> Map.values() |> List.flatten()
      Enum.each(keys, fn key ->
        route = Enum.find(routes, &(&1.key == key))
        state = if route, do: route.enabled, else: nil
        AuditLog.append("admin", "hide", key, state, nil)
      end)
    end

    {:noreply, load_dashboard(socket) |> clear_selection()}
  end

  def handle_event("show_hidden_modal", _params, socket) do
    routes = socket.assigns.grouped_routes |> Map.values() |> List.flatten()
    hidden_keys = HiddenRoutes.all_keys()
    hidden_routes = Enum.filter(routes, fn r -> r.key in hidden_keys end)
    {:noreply, assign(socket, show_hidden_modal: true, hidden_routes_list: hidden_routes)}
  end

  def handle_event("close_hidden_modal", _params, socket) do
    {:noreply, assign(socket, show_hidden_modal: false)}
  end

  def handle_event("show_route", %{"key" => key}, socket) do
    HiddenRoutes.show([key])

    routes = socket.assigns.grouped_routes |> Map.values() |> List.flatten()
    route = Enum.find(routes, &(&1.key == key))
    state = if route, do: route.enabled, else: nil
    AuditLog.append("admin", "show", key, state, nil)

    hidden_keys = HiddenRoutes.all_keys()
    hidden_routes = Enum.filter(routes, fn r -> r.key in hidden_keys end)

    {:noreply, load_dashboard(socket) |> assign(hidden_routes_list: hidden_routes)}
  end

  # --- Reset all ---

  def handle_event("confirm_reset", _params, socket) do
    {:noreply, assign(socket, show_confirm_reset: true)}
  end

  def handle_event("cancel_reset", _params, socket) do
    {:noreply, assign(socket, show_confirm_reset: false)}
  end

  def handle_event("reset_all", _params, socket) do
    RoutePolicies.reset_all()
    AuditLog.append("admin", "reset_all", "—", "—", "—")
    {:noreply, load_dashboard(socket) |> assign(show_confirm_reset: false)}
  end

  # --- Dead render fallback (query params) ---

  @impl true
  def handle_params(%{"toggle" => key}, uri, socket) do
    route = find_route(socket.assigns.grouped_routes, key)

    if route && route.mutable do
      new_state = not route.enabled
      RoutePolicies.set_route_enabled(key, new_state)
      AuditLog.append("admin", "toggle", key, route.enabled, new_state)
    end

    clean_path = URI.parse(uri).path

    {:noreply,
     socket
     |> load_dashboard()
     |> push_patch(to: clean_path, replace: true)}
  end

  def handle_params(%{"toggle_group" => group}, uri, socket) do
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

  def handle_params(_params, uri, socket) do
    {:noreply, assign(socket, :console_path, URI.parse(uri).path)}
  end

  # --- Render ---

  @impl true
  def render(assigns) do
    ~H"""
    <div class="console-root">
      <style>
        html, body { background: #fff !important; }
        .console-root { font-family: system-ui, sans-serif; max-width: 960px; margin: 2rem auto; padding: 0 1rem 6rem 1rem; background: #fff; }
        @media (prefers-color-scheme: dark) {
          html, body { background: #0f172a !important; }
          .console-root { background: #0f172a; color: #e2e8f0; }
          .console-card { background: #1e293b !important; border-color: #334155 !important; }
          .console-group-card { background: #1e293b !important; border-color: #334155 !important; }
          .console-route-enabled { background: #052e16 !important; border-color: #166534 !important; }
          .console-route-disabled { background: #450a0a !important; border-color: #7f1d1d !important; }
          .console-route-immutable { background: #1e293b !important; border-color: #334155 !important; }
          .console-method-badge { background: #1e293b !important; color: #93c5fd !important; }
          .console-stat-label { color: #94a3b8 !important; }
          .console-powered-by { color: #475569 !important; }
          .console-progress-bg { background: #334155 !important; }
          .console-search { background: #1e293b !important; border-color: #334155 !important; color: #e2e8f0 !important; }
          .console-group-btn { background: #1e293b !important; border-color: #475569 !important; color: #e2e8f0 !important; }
          .console-audit-panel { background: #1e293b !important; border-color: #334155 !important; }
          .console-audit-toggle { background: #1e293b !important; color: #e2e8f0 !important; }
          .console-audit-toggle:hover { background: #334155 !important; }
          .console-bulk-bar { background: #1e3a5f !important; border-color: #3b82f6 !important; }
          .console-audit-row { border-color: #334155 !important; }
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
        .console-group-card { background: #fff; border: 1px solid #e5e7eb; border-radius: 24px; padding: 1.25rem; margin-bottom: 1rem; }
        .console-group-header { display: flex; flex-wrap: wrap; justify-content: space-between; align-items: center; gap: 0.75rem; margin-bottom: 1rem; }
        .console-group-name { font-size: 1.1rem; font-weight: 600; margin: 0; }
        .console-group-count { font-size: 0.75rem; color: #6b7280; }
        .console-group-btn { border: 1px solid #d1d5db; border-radius: 999px; padding: 0.5rem 1rem; font-size: 0.75rem; font-weight: 600; text-transform: uppercase; background: #fff; cursor: pointer; transition: all 0.15s; color: #374151; text-decoration: none; display: inline-block; }
        .console-group-btn:hover { border-color: #3b82f6; color: #2563eb; }
        .console-route-row { display: flex; align-items: center; gap: 0.75rem; padding: 0.75rem; border-radius: 16px; border: 1px solid; margin-bottom: 0.5rem; transition: all 0.15s; }
        .console-route-enabled { border-color: #bbf7d0; background: #f0fdf4; }
        .console-route-disabled { border-color: #fecaca; background: #fef2f2; }
        .console-route-immutable { border-color: #e5e7eb; background: #f9fafb; opacity: 0.6; }
        .console-route-left { min-width: 0; flex: 1; }
        .console-route-meta { display: flex; align-items: center; gap: 0.5rem; }
        .console-method-badge { background: #e5e7eb; padding: 2px 8px; border-radius: 6px; font-size: 0.7rem; font-weight: 700; text-transform: uppercase; }
        .console-route-path { font-size: 0.875rem; font-weight: 500; margin: 0.25rem 0 0 0; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
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
        .console-search { width: 100%; padding: 0.5rem 0.75rem; border: 1px solid #e5e7eb; border-radius: 12px; font-size: 0.875rem; outline: none; margin-bottom: 1rem; }
        .console-search:focus { border-color: #3b82f6; box-shadow: 0 0 0 2px rgba(59,130,246,0.15); }
        .console-checkbox { width: 18px; height: 18px; cursor: pointer; accent-color: #3b82f6; flex-shrink: 0; }
        .console-select-all { font-size: 0.75rem; color: #3b82f6; cursor: pointer; border: none; background: none; padding: 0; text-decoration: underline; }
        .console-bulk-bar { position: fixed; bottom: 1.5rem; left: 50%; transform: translateX(-50%); background: #fff; border: 1px solid #3b82f6; border-radius: 16px; padding: 0.75rem 1.5rem; display: flex; align-items: center; gap: 1rem; box-shadow: 0 4px 24px rgba(0,0,0,0.12); z-index: 100; font-size: 0.875rem; }
        .console-bulk-btn { border: none; border-radius: 8px; padding: 0.4rem 0.75rem; font-size: 0.75rem; font-weight: 600; cursor: pointer; }
        .console-bulk-enable { background: #166534; color: #fff; }
        .console-bulk-disable { background: #991b1b; color: #fff; }
        .console-bulk-clear { background: #e5e7eb; color: #374151; }
        .console-audit-panel { border: 1px solid #e5e7eb; border-radius: 16px; margin-bottom: 1.5rem; overflow: hidden; }
        .console-audit-toggle { width: 100%; padding: 0.75rem 1rem; text-align: left; background: #f3f4f6; border: none; cursor: pointer; font-weight: 600; font-size: 0.9rem; display: flex; justify-content: space-between; align-items: center; color: #374151; }
        .console-audit-toggle:hover { background: #e5e7eb; }
        .console-audit-body { padding: 0.75rem 1rem 1rem 1rem; }
        .console-audit-row { display: flex; justify-content: space-between; align-items: center; padding: 0.6rem 0; border-bottom: 1px solid #f1f5f9; font-size: 0.8rem; gap: 1rem; }
        .console-audit-row:last-child { border-bottom: none; }
        .console-audit-left { display: flex; align-items: center; gap: 0.5rem; min-width: 0; }
        .console-audit-route { font-family: monospace; font-size: 0.75rem; color: #6b7280; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
        .console-audit-badge { padding: 2px 8px; border-radius: 4px; font-size: 0.65rem; font-weight: 700; text-transform: uppercase; flex-shrink: 0; }
        .console-audit-badge-on { background: #dcfce7; color: #166534; }
        .console-audit-badge-off { background: #fee2e2; color: #991b1b; }
        .console-audit-badge-hidden { background: #ede9fe; color: #6b21a8; }
        .console-audit-badge-shown { background: #dbeafe; color: #1e40af; }
        .console-audit-badge-reset { background: #fee2e2; color: #991b1b; }
        .console-audit-arrow { color: #9ca3af; font-size: 0.7rem; margin: 0 2px; }
        .console-audit-time { color: #9ca3af; font-size: 0.7rem; flex-shrink: 0; }
        .console-audit-download { font-size: 0.75rem; color: #3b82f6; cursor: pointer; border: none; background: none; padding: 0; margin-left: 0.75rem; text-decoration: none; }
        .console-audit-download:hover { text-decoration: underline; }
        .console-reset-btn { background: #991b1b; color: #fff; border: none; padding: 0.4rem 1rem; border-radius: 8px; font-size: 0.8rem; font-weight: 600; cursor: pointer; }
        .console-reset-btn:hover { background: #7f1d1d; }
        .console-hidden-count { color: #8b5cf6; cursor: pointer; border: none; background: none; padding: 0; font-size: 0.875rem; font-weight: 600; text-decoration: underline; }
        .console-hidden-count:hover { color: #7c3aed; }
        .console-modal-overlay { position: fixed; inset: 0; background: rgba(0,0,0,0.5); display: flex; align-items: center; justify-content: center; z-index: 200; }
        .console-modal { background: #fff; border-radius: 16px; padding: 1.5rem; min-width: 400px; max-width: 600px; max-height: 80vh; overflow-y: auto; box-shadow: 0 8px 32px rgba(0,0,0,0.2); }
        @media (prefers-color-scheme: dark) {
          .console-modal { background: #1e293b; color: #e2e8f0; }
        }
      </style>

      <div class="console-card">
        <div class="console-header-row">
          <div>
            <h1 class="console-title">
              <%= Branding.app_name() %>
              <span class={"console-connection-badge " <> if(@connected, do: "console-connection-live", else: "console-connection-static")}>
                <%= if @connected, do: "LIVE", else: "STATIC" %>
              </span>
              <button
                phx-click="toggle_grouping"
                class="console-group-btn"
                style="margin-left:0.5rem;font-size:0.65rem;padding:0.25rem 0.5rem;"
              >
                <%= if @group_by_controller, do: "Grouped", else: "Flat" %>
              </button>
            </h1>
            <p class="console-subtitle">Control route availability in real time.</p>
          </div>
          <div class="console-stats">
            <div>
              <span class="console-stat-enabled"><%= @stats.enabled %> enabled</span>
              <%= if @stats.disabled > 0 do %>
                / <span class="console-stat-disabled"><%= @stats.disabled %> disabled</span>
              <% end %>
              <%= if @stats.hidden > 0 do %>
                / <button phx-click="show_hidden_modal" class="console-hidden-count"><%= @stats.hidden %> hidden</button>
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

        <input
          type="text"
          placeholder="Search routes by path, method, or controller..."
          phx-keyup="search"
          phx-debounce="200"
          value={@search_query}
          class="console-search"
        />

        <%= if Enum.count(@selected_keys) > 0 do %>
          <div style="display:flex;align-items:center;gap:0.5rem;margin-top:0.5rem;">
            <span class="console-stat-label"><%= Enum.count(@selected_keys) %> selected</span>
            <button phx-click="deselect_all" class="console-select-all">Clear</button>
          </div>
        <% end %>

        <%= if not @connected do %>
          <p style="margin-top:1rem; font-size:0.8rem; color:#b45309; background:#fef3c7; padding:0.5rem 0.75rem; border-radius:6px;">
            💡 Toggles work but cause a page reload. For instant toggles, add LiveView JS to your app.
          </p>
        <% end %>

        <div style="display:flex;align-items:center;gap:0.5rem;margin-top:0.75rem;">
          <button phx-click="confirm_reset" class="console-reset-btn" title="This will re-enable ALL disabled routes. This cannot be undone.">
            ⚠ Reset All Policies
          </button>
        </div>
      </div>

      <%= for {group, routes} <- @filtered_routes || @grouped_routes do %>
        <% mutable_in_group = Enum.filter(routes, & &1.mutable) %>
        <div class="console-group-card">
          <div class="console-group-header">
            <div>
              <h2 class="console-group-name"><%= group %></h2>
              <span class="console-group-count"><%= Enum.count(routes) %> routes</span>
            </div>
            <div style="display:flex;align-items:center;gap:0.5rem;">
              <button phx-click="select_all" phx-value-group={group} class="console-select-all">Select All</button>
              <button phx-click="deselect_group" phx-value-group={group} class="console-select-all">Clear</button>
              <%= if Enum.count(mutable_in_group) > 0 do %>
                <button phx-click="toggle_group" phx-value-group={group} class="console-group-btn">
                  Toggle Group
                </button>
              <% end %>
            </div>
          </div>

          <%= for route <- routes do %>
            <% selected = MapSet.member?(@selected_keys, route.key) %>
            <div class={
              "console-route-row " <>
              cond do
                not route.mutable -> "console-route-immutable"
                route.enabled -> "console-route-enabled"
                true -> "console-route-disabled"
              end
            }>
              <input
                :if={route.mutable}
                type="checkbox"
                class="console-checkbox"
                checked={selected}
                phx-click="select"
                phx-value-key={route.key}
              />

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

      <div class="console-audit-panel">
        <button phx-click="toggle_audit" class="console-audit-toggle">
          <span>
            📋 Audit Log
            <a href={"#{@console_path}/audit.csv"} class="console-audit-download">Download CSV</a>
          </span>
          <span><%= if @audit_expanded, do: "▲", else: "▼" %></span>
        </button>

        <%= if @audit_expanded do %>
          <div class="console-audit-body">
            <%= for entry <- @audit_entries do %>
              <div class="console-audit-row">
                <div class="console-audit-left">
                  <%= if entry.action in ["hide", "show"] do %>
                    <span class={"console-audit-badge " <> if(entry.action == "hide", do: "console-audit-badge-hidden", else: "console-audit-badge-shown")}>
                      <%= String.upcase(entry.action) %>
                    </span>
                    <span class="console-stat-label"><%= if entry.old_state, do: "ON", else: "OFF" %></span>
                  <% else %>
                    <%= if entry.action == "reset_all" do %>
                      <span class="console-audit-badge console-audit-badge-reset">RESET ALL</span>
                    <% else %>
                      <span class={"console-audit-badge " <> if(entry.old_state, do: "console-audit-badge-on", else: "console-audit-badge-off")}>
                        <%= if entry.old_state, do: "ON", else: "OFF" %>
                      </span>
                      <span class="console-audit-arrow">→</span>
                      <span class={"console-audit-badge " <> if(entry.new_state, do: "console-audit-badge-on", else: "console-audit-badge-off")}>
                        <%= if entry.new_state, do: "ON", else: "OFF" %>
                      </span>
                    <% end %>
                  <% end %>
                  <span class="console-audit-route"><%= entry.key %></span>
                </div>
                <span class="console-audit-time"><%= entry.timestamp %></span>
              </div>
            <% end %>

            <%= if @audit_offset < @audit_total do %>
              <button
                phx-click="load_more_audit"
                class="console-group-btn"
                style="margin-top:0.75rem;display:block;width:100%;text-align:center;"
              >
                Load more (<%= @audit_total - @audit_offset %> remaining)
              </button>
            <% end %>

            <%= if @audit_entries == [] do %>
              <p class="console-stat-label" style="text-align:center;padding:1rem;">No audit entries yet.</p>
            <% end %>
          </div>
        <% end %>
      </div>

      <%= if Enum.count(@selected_keys) > 0 do %>
        <div class="console-bulk-bar">
          <span><strong><%= Enum.count(@selected_keys) %></strong> routes selected</span>
          <button phx-click="bulk_enable" class="console-bulk-btn console-bulk-enable">Enable All</button>
          <button phx-click="bulk_disable" class="console-bulk-btn console-bulk-disable">Disable All</button>
          <button phx-click="hide_selected" class="console-bulk-btn console-bulk-clear">Hide</button>
          <button phx-click="deselect_all" class="console-bulk-btn console-bulk-clear">✕</button>
        </div>
      <% end %>

      <p class="console-powered-by"><%= if not Branding.hide_powered_by?, do: "Powered by API Management Console" %></p>
    </div>

    <%= if @show_confirm_reset do %>
      <div class="console-modal-overlay">
        <div class="console-modal">
          <h3>⚠ Reset All Policies?</h3>
          <p>This will re-enable ALL disabled routes. This action cannot be undone.</p>
          <div style="display:flex;gap:0.5rem;margin-top:1rem;justify-content:flex-end;">
            <button phx-click="cancel_reset" class="console-group-btn">Cancel</button>
            <button phx-click="reset_all" class="console-bulk-btn console-bulk-disable">Yes, Reset All</button>
          </div>
        </div>
      </div>
    <% end %>

    <%= if @show_hidden_modal do %>
      <div class="console-modal-overlay" phx-click="close_hidden_modal">
        <div class="console-modal" phx-click-away="close_hidden_modal">
          <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:1rem;">
            <h3>Hidden Routes</h3>
            <button phx-click="close_hidden_modal" style="border:none;background:none;cursor:pointer;font-size:1.2rem;">✕</button>
          </div>
          <%= if @hidden_routes_list == [] do %>
            <p class="console-stat-label">No hidden routes.</p>
          <% else %>
            <%= for route <- @hidden_routes_list do %>
              <div class="console-audit-row">
                <div class="console-audit-left">
                  <span class="console-method-badge"><%= route.method %></span>
                  <span class="console-audit-route"><%= route.path %></span>
                </div>
                <button phx-click="show_route" phx-value-key={route.key} class="console-bulk-btn console-bulk-enable">Show</button>
              </div>
            <% end %>
          <% end %>
        </div>
      </div>
    <% end %>
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

    socket
    |> assign(:grouped_routes, grouped_routes)
    |> assign(:stats, compute_stats(grouped_routes))
    |> apply_search()
  end

  defp apply_search(socket) do
    query = String.trim(socket.assigns.search_query)
    grouped = socket.assigns.grouped_routes

    hidden_keys = HiddenRoutes.all_keys()

    filter_hidden = fn routes ->
      Enum.reject(routes, fn r -> r.key in hidden_keys end)
    end

    {all_routes, filtered} =
      if query == "" do
        {grouped, grouped}
      else
        filtered =
          Enum.reduce(grouped, %{}, fn {group, routes}, acc ->
            matching = Enum.filter(routes, fn r ->
              r.key not in hidden_keys and
                (String.contains?(String.downcase(r.path), String.downcase(query)) or
                 String.contains?(String.downcase(r.method), String.downcase(query)) or
                 String.contains?(String.downcase(to_string(r.controller)), String.downcase(query)))
            end)

            if matching != [], do: Map.put(acc, group, matching), else: acc
          end)

        {grouped, filtered}
      end

    # Also filter hidden from the base routes used for display
    filtered = Map.new(filtered, fn {group, routes} -> {group, filter_hidden.(routes)} end)
      |> Enum.reject(fn {_, routes} -> routes == [] end)
      |> Map.new()

    final =
      if socket.assigns.group_by_controller do
        filtered
      else
        flat = Map.values(filtered) |> List.flatten()
        if flat == [], do: %{}, else: %{"All Routes" => flat}
      end

    Logger.debug("[ApiConsole] search — query=#{inspect(query)}, groups=#{map_size(final)}, total=#{stats_for(final).total}")

    socket
    |> assign(:filtered_routes, final)
    |> assign(:stats, stats_for(all_routes))
  end

  defp stats_for(grouped_routes) do
    compute_stats(grouped_routes)
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
    hidden = HiddenRoutes.count()
    ratio = if total > 0, do: disabled / total, else: 0.0

    %{total: total, enabled: enabled, disabled: disabled, hidden: hidden, disabled_ratio: ratio}
  end

  defp find_route(grouped_routes, key) do
    grouped_routes
    |> Map.values()
    |> List.flatten()
    |> Enum.find(&(&1.key == key))
  end

  defp clear_selection(socket) do
    assign(socket, :selected_keys, MapSet.new())
  end

  defp mutable_keys(grouped_routes) do
    grouped_routes
    |> Map.values()
    |> List.flatten()
    |> Enum.filter(& &1.mutable)
    |> Enum.map(& &1.key)
  end
end
