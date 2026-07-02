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
    • Role-based access (Admin / Viewer)
    • Account management (Admin only)
    • Works in LIVE and STATIC modes
  """

  use Phoenix.LiveView

  require Logger

  import ApiManagementConsoleV2.Debug, only: [log: 1]

  alias ApiManagementConsoleV2.{Accounts, AuditLog, Branding, Features, HiddenRoutes, License, RoutePolicies}

  @page_size 10

  @admin_events ~w(toggle toggle_group bulk_enable bulk_disable hide_selected
                   reset_all add_account delete_account show_route)

  @impl true
  def mount(_params, session, socket) do
    log("[ApiConsole] mount — connected?=#{connected?(socket)}, router=#{inspect(socket.router)}")

    RoutePolicies.start_link([])

    user = session["api_console_user"] || %{"username" => "admin", "role" => "admin"}
    user = %{username: user["username"], role: String.to_existing_atom(user["role"])}

    socket =
      socket
      |> assign(:grouped_routes, %{})
      |> assign(:stats, %{total: 0, enabled: 0, disabled: 0, hidden: 0, disabled_ratio: 0.0})
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
      |> assign(:current_user, user)
      |> assign(:show_accounts, false)
      |> assign(:account_list, [])
      |> assign(:show_upgrade_notice, upgrade_notice?())
      |> assign(:show_plans_modal, false)
      |> assign(:show_user_limit_popup, false)
      |> assign(:teaser_routes, [])
      |> assign(:routes_over_cap, 0)

    {:ok, load_dashboard(socket)}
  end

  # --- Centralized admin guard ---

  @impl true
  def handle_event(event, params, socket) do
    if event in @admin_events and not is_admin?(socket) do
      {:noreply, socket}
    else
      do_handle_event(event, params, socket)
    end
  end

  # --- Single toggle ---

  defp do_handle_event("toggle", %{"key" => key}, socket) do
    route = find_route(socket.assigns.grouped_routes, key)

    if route && route.mutable do
      new_state = not route.enabled
      RoutePolicies.set_route_enabled(key, new_state)
      AuditLog.append(username(socket), "toggle", key, route.enabled, new_state)
    end

    {:noreply, load_dashboard(socket) |> clear_selection()}
  end

  # --- Group toggle ---

  defp do_handle_event("toggle_group", %{"group" => group}, socket) do
    routes = Map.get(socket.assigns.grouped_routes, group, [])
    mutable = Enum.filter(routes, & &1.mutable)

    if mutable != [] do
      disable_all? = Enum.all?(mutable, & &1.enabled)
      new_state = not disable_all?
      RoutePolicies.set_group_enabled(socket.router, group, new_state)

      Enum.each(mutable, fn r ->
        AuditLog.append(username(socket), "toggle_group", "#{group}/*", r.enabled, new_state)
      end)
    end

    {:noreply, load_dashboard(socket) |> clear_selection()}
  end

  # --- Search ---

  defp do_handle_event("search", %{"value" => query}, socket) do
    {:noreply, socket |> assign(:search_query, query) |> apply_search()}
  end

  # --- Bulk selection ---

  defp do_handle_event("select", %{"key" => key}, socket) do
    selected =
      if MapSet.member?(socket.assigns.selected_keys, key) do
        MapSet.delete(socket.assigns.selected_keys, key)
      else
        MapSet.put(socket.assigns.selected_keys, key)
      end

    {:noreply, assign(socket, :selected_keys, selected)}
  end

  defp do_handle_event("select_all", %{"group" => group}, socket) do
    routes = Map.get(socket.assigns.filtered_routes || socket.assigns.grouped_routes, group, [])
    keys = Enum.filter(routes, & &1.mutable) |> Enum.map(& &1.key)
    {:noreply, assign(socket, :selected_keys, MapSet.union(socket.assigns.selected_keys, MapSet.new(keys)))}
  end

  defp do_handle_event("select_all", _params, socket) do
    all_keys = mutable_keys(socket.assigns.filtered_routes || socket.assigns.grouped_routes)
    {:noreply, assign(socket, :selected_keys, MapSet.new(all_keys))}
  end

  defp do_handle_event("deselect_group", %{"group" => group}, socket) do
    routes = Map.get(socket.assigns.filtered_routes || socket.assigns.grouped_routes, group, [])
    keys = Enum.filter(routes, & &1.mutable) |> Enum.map(& &1.key) |> MapSet.new()
    {:noreply, assign(socket, :selected_keys, MapSet.difference(socket.assigns.selected_keys, keys))}
  end

  defp do_handle_event("deselect_all", _params, socket) do
    {:noreply, assign(socket, :selected_keys, MapSet.new())}
  end

  defp do_handle_event("bulk_enable", _params, socket) do
    updates = Enum.map(socket.assigns.selected_keys, &{&1, true})
    RoutePolicies.Store.bulk_put(updates)

    Enum.each(socket.assigns.selected_keys, fn key ->
      AuditLog.append(username(socket), "bulk_enable", key, nil, true)
    end)

    {:noreply, load_dashboard(socket) |> clear_selection()}
  end

  defp do_handle_event("bulk_disable", _params, socket) do
    updates = Enum.map(socket.assigns.selected_keys, &{&1, false})
    RoutePolicies.Store.bulk_put(updates)

    Enum.each(socket.assigns.selected_keys, fn key ->
      AuditLog.append(username(socket), "bulk_disable", key, nil, false)
    end)

    {:noreply, load_dashboard(socket) |> clear_selection()}
  end

  # --- Grouping toggle ---

  defp do_handle_event("toggle_grouping", _params, socket) do
    {:noreply, socket |> assign(:group_by_controller, not socket.assigns.group_by_controller) |> apply_search()}
  end

  # --- Audit log ---

  defp do_handle_event("toggle_audit", _params, socket) do
    if socket.assigns.audit_expanded do
      {:noreply, assign(socket, :audit_expanded, false)}
    else
      {entries, total} = AuditLog.list(offset: 0, limit: @page_size)
      {:noreply, assign(socket, audit_expanded: true, audit_entries: entries, audit_offset: @page_size, audit_total: total)}
    end
  end

  defp do_handle_event("load_more_audit", _params, socket) do
    {entries, total} = AuditLog.list(offset: socket.assigns.audit_offset, limit: @page_size)
    all = socket.assigns.audit_entries ++ entries
    {:noreply, assign(socket, audit_entries: all, audit_offset: socket.assigns.audit_offset + @page_size, audit_total: total)}
  end

  # --- Hide routes ---

  defp do_handle_event("hide_selected", _params, socket) do
    keys = MapSet.to_list(socket.assigns.selected_keys)

    if keys != [] do
      HiddenRoutes.hide(keys)
      routes = socket.assigns.grouped_routes |> Map.values() |> List.flatten()
      Enum.each(keys, fn key ->
        route = Enum.find(routes, &(&1.key == key))
        state = if route, do: route.enabled, else: nil
        AuditLog.append(username(socket), "hide", key, state, nil)
      end)
    end

    {:noreply, load_dashboard(socket) |> clear_selection()}
  end

  defp do_handle_event("show_hidden_modal", _params, socket) do
    routes = socket.assigns.grouped_routes |> Map.values() |> List.flatten()
    hidden_keys = HiddenRoutes.all_keys()
    hidden_routes = Enum.filter(routes, fn r -> r.key in hidden_keys end)
    {:noreply, assign(socket, show_hidden_modal: true, hidden_routes_list: hidden_routes)}
  end

  defp do_handle_event("close_hidden_modal", _params, socket) do
    {:noreply, assign(socket, show_hidden_modal: false)}
  end

  defp do_handle_event("show_route", %{"key" => key}, socket) do
    HiddenRoutes.show([key])

    routes = socket.assigns.grouped_routes |> Map.values() |> List.flatten()
    route = Enum.find(routes, &(&1.key == key))
    state = if route, do: route.enabled, else: nil
    AuditLog.append(username(socket), "show", key, state, nil)

    hidden_keys = HiddenRoutes.all_keys()
    hidden_routes = Enum.filter(routes, fn r -> r.key in hidden_keys end)

    {:noreply, load_dashboard(socket) |> assign(hidden_routes_list: hidden_routes)}
  end

  # --- Reset all ---

  defp do_handle_event("confirm_reset", _params, socket) do
    {:noreply, assign(socket, show_confirm_reset: true)}
  end

  defp do_handle_event("cancel_reset", _params, socket) do
    {:noreply, assign(socket, show_confirm_reset: false)}
  end

  defp do_handle_event("reset_all", _params, socket) do
    RoutePolicies.reset_all()
    AuditLog.append(username(socket), "reset_all", "—", "—", "—")
    {:noreply, load_dashboard(socket) |> assign(show_confirm_reset: false)}
  end

  # --- Account management ---

  defp do_handle_event("dismiss_upgrade_notice", _params, socket) do
    {:noreply, assign(socket, show_upgrade_notice: false)}
  end

  defp do_handle_event("show_plans_modal", _params, socket) do
    {:noreply, assign(socket, show_plans_modal: true, show_user_limit_popup: false)}
  end

  defp do_handle_event("close_plans_modal", _params, socket) do
    {:noreply, assign(socket, show_plans_modal: false)}
  end

  defp do_handle_event("dismiss_user_limit_popup", _params, socket) do
    {:noreply, assign(socket, show_user_limit_popup: false)}
  end

  defp do_handle_event("toggle_accounts", _params, socket) do
    if socket.assigns.show_accounts do
      {:noreply, assign(socket, show_accounts: false)}
    else
      {:noreply, assign(socket, show_accounts: true, account_list: Accounts.list())}
    end
  end

  defp do_handle_event("add_account", %{"username" => username, "password" => password, "role" => role}, socket) do
    if Accounts.can_create?() do
      role_atom = String.to_existing_atom(role)

      case Accounts.create(username, password, role_atom) do
        :ok ->
          AuditLog.append(username(socket), "add_account", username, nil, nil)
          {:noreply, assign(socket, account_list: Accounts.list())}

        {:error, _} ->
          {:noreply, socket}
      end
    else
      {:noreply, assign(socket, show_user_limit_popup: true)}
    end
  end

  defp do_handle_event("delete_account", %{"username" => username}, socket) do
    Accounts.delete(username)
    AuditLog.append(username(socket), "delete_account", username, nil, nil)
    {:noreply, assign(socket, account_list: Accounts.list())}
  end

  # --- Dead render fallback (query params) ---

  @impl true
  def handle_params(%{"toggle" => key}, uri, socket) do
    route = find_route(socket.assigns.grouped_routes, key)

    if route && route.mutable do
      new_state = not route.enabled
      RoutePolicies.set_route_enabled(key, new_state)
      AuditLog.append(username(socket), "toggle", key, route.enabled, new_state)
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
        .console-teaser-wrap { position: relative; max-height: 220px; overflow: hidden; border-radius: 16px; margin-bottom: 1rem; }
        .console-teaser-wrap::after { content: ""; position: absolute; bottom: 0; left: 0; right: 0; height: 120px; background: linear-gradient(to bottom, transparent 0%, rgba(249,250,251,0.85) 40%, rgba(249,250,251,1) 100%); pointer-events: none; border-radius: 0 0 16px 16px; }
        @media (prefers-color-scheme: dark) {
          .console-teaser-wrap::after { background: linear-gradient(to bottom, transparent 0%, rgba(15,23,42,0.85) 40%, rgba(15,23,42,1) 100%); }
        }
        .console-teaser-lock { position: absolute; bottom: 16px; left: 50%; transform: translateX(-50%); display: flex; flex-direction: column; align-items: center; gap: 6px; z-index: 5; }
        .console-teaser-lock svg { width: 22px; height: 22px; color: #9ca3af; }
        .console-teaser-lock-text { font-size: 0.8rem; font-weight: 600; color: #6b7280; }
        .console-teaser-lock-btn { background: linear-gradient(135deg, #3b82f6, #8b5cf6); color: #fff; border: none; padding: 0.4rem 1.25rem; border-radius: 8px; font-size: 0.78rem; font-weight: 700; cursor: pointer; box-shadow: 0 2px 12px rgba(59,130,246,0.3); }
        .console-teaser-lock-btn:hover { opacity: 0.9; }
      </style>

      <div class="console-card">
        <div class="console-header-row">
          <div>
            <h1 class="console-title">
              <%= Branding.app_name() %>
              <span class={"console-connection-badge " <> if(@connected, do: "console-connection-live", else: "console-connection-static")}>
                <%= if @connected, do: "LIVE", else: "STATIC" %>
              </span>
              <button phx-click="toggle_grouping" class="console-group-btn" style="margin-left:0.5rem;font-size:0.65rem;padding:0.25rem 0.5rem;">
                <%= if @group_by_controller, do: "Grouped", else: "Flat" %>
              </button>
            </h1>
            <p class="console-subtitle">Control route availability in real time.</p>
            <div style="margin-top:0.5rem;display:flex;align-items:center;gap:0.5rem;flex-wrap:wrap;">
              <span style="font-size:0.75rem;color:#6b7280;">
                Logged in as <strong><%= @current_user.username %></strong>
                (<%= if @current_user.role == :admin, do: "Admin", else: "Viewer" %>)
              </span>
              <a href={"#{@console_path}/logout"} style="font-size:0.75rem;color:#3b82f6;text-decoration:none;">Logout</a>
              <span style={"font-size:0.65rem;font-weight:600;padding:2px 8px;border-radius:4px;" <> tier_badge_style(License.get_tier())}>
                <%= tier_label(License.get_tier()) %>
              </span>
              <button phx-click="show_plans_modal" style="font-size:0.7rem;color:#3b82f6;background:none;border:1px solid #3b82f6;border-radius:6px;padding:2px 8px;cursor:pointer;">Compare Plans</button>
            </div>
          </div>
          <div class="console-stats">
            <div>
              <span class="console-stat-enabled"><%= @stats.enabled %> enabled</span>
              / <span class="console-stat-disabled"><%= @stats.disabled %> disabled</span>
              / <button phx-click="show_hidden_modal" class="console-hidden-count"><%= @stats.hidden %> hidden</button>
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

        <input type="text" placeholder="Search routes by path, method, or controller..." phx-keyup="search" phx-debounce="200" value={@search_query} class="console-search" />

        <div style="display:flex;align-items:center;gap:0.5rem;margin-top:0.75rem;">
          <button phx-click="confirm_reset" class="console-reset-btn" title="This will re-enable ALL disabled routes.">⚠ Reset All Policies</button>
        </div>

        <%= if not @connected do %>
          <p style="margin-top:1rem; font-size:0.8rem; color:#b45309; background:#fef3c7; padding:0.5rem 0.75rem; border-radius:6px;">
            💡 Toggles work but cause a page reload. For instant toggles, add LiveView JS to your app.
          </p>
        <% end %>
      </div>

      <%= if @show_upgrade_notice do %>
        <div class="console-upgrade-notice">
          <style>
            .console-upgrade-notice { background:#fef3c7; border:1px solid #f59e0b; border-radius:12px; padding:0.75rem 1rem; margin-bottom:1rem; display:flex; justify-content:space-between; align-items:center; }
            .console-upgrade-notice span { font-size:0.85rem; color:#92400e; }
            .console-upgrade-notice button { border:none; background:none; cursor:pointer; color:#92400e; font-size:1.1rem; }
            @media (prefers-color-scheme: dark) {
              .console-upgrade-notice { background:#422006; border-color:#92400e; }
              .console-upgrade-notice span { color:#fcd34d; }
              .console-upgrade-notice button { color:#fcd34d; }
            }
          </style>
          <span>
            💡 Branding config is set but requires a paid license. <strong>Upgrade to unlock custom branding.</strong>
          </span>
          <button phx-click="dismiss_upgrade_notice">✕</button>
        </div>
      <% end %>

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
                <button phx-click="toggle_group" phx-value-group={group} class="console-group-btn">Toggle Group</button>
              <% end %>
            </div>
          </div>

          <%= for route <- routes do %>
            <% selected = MapSet.member?(@selected_keys, route.key) %>
            <div class={"console-route-row " <> cond do
              not route.mutable -> "console-route-immutable"
              route.enabled -> "console-route-enabled"
              true -> "console-route-disabled"
            end}>
              <input :if={route.mutable} type="checkbox" class="console-checkbox" checked={selected} phx-click="select" phx-value-key={route.key} />
              <div class="console-route-left">
                <div class="console-route-meta">
                  <span class="console-method-badge"><%= route.method %></span>
                  <span class="console-stat-label"><%= route.controller %>.<%= route.action %></span>
                </div>
                <p class="console-route-path"><%= route.path %></p>
              </div>

              <button :if={route.mutable} phx-click="toggle" phx-value-key={route.key} class={"console-toggle " <> if(route.enabled, do: "console-toggle-on", else: "console-toggle-off")}>
                <span class={"console-toggle-knob " <> if(route.enabled, do: "console-toggle-knob-on", else: "console-toggle-knob-off")} />
              </button>
              <span :if={not route.mutable} class="console-toggle console-toggle-immutable">
                <span class="console-toggle-knob console-toggle-knob-on" />
              </span>
            </div>
          <% end %>
        </div>
      <% end %>

      <%= if @routes_over_cap > 0 do %>
        <div class="console-teaser-wrap">
          <div style="padding:0.75rem 0;">
            <%= for route <- @teaser_routes do %>
              <div class={"console-route-row " <> if(route.enabled, do: "console-route-enabled", else: "console-route-disabled")} style="pointer-events:none;opacity:0.55;">
                <div class="console-route-left">
                  <div class="console-route-meta">
                    <span class="console-method-badge"><%= route.method %></span>
                    <span class="console-stat-label"><%= route.controller %>.<%= route.action %></span>
                  </div>
                  <p class="console-route-path"><%= route.path %></p>
                </div>
                <span class="console-toggle console-toggle-immutable">
                  <span class="console-toggle-knob console-toggle-knob-on" />
                </span>
              </div>
            <% end %>
          </div>
          <div class="console-teaser-lock">
            <svg fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"/>
            </svg>
            <span class="console-teaser-lock-text"><%= @routes_over_cap %> route<%= if @routes_over_cap > 1, do: "s", else: "" %> hidden</span>
            <button phx-click="show_plans_modal" class="console-teaser-lock-btn">Upgrade to PRO</button>
          </div>
        </div>
      <% end %>

      <div class="console-audit-panel">
        <button phx-click="toggle_audit" class="console-audit-toggle">
          <span>📋 Audit Log<a href={"#{@console_path}/audit.csv"} class="console-audit-download">Download CSV</a></span>
          <span><%= if @audit_expanded, do: "▲", else: "▼" %></span>
        </button>
        <%= if @audit_expanded do %>
          <div class="console-audit-body">
            <%= for entry <- @audit_entries do %>
              <div class="console-audit-row">
                <span style="font-size:0.65rem;color:#9ca3af;min-width:60px;"><%= entry.who %></span>
                <div class="console-audit-left">
                  <%= if entry.action in ["hide", "show"] do %>
                    <span class={"console-audit-badge " <> if(entry.action == "hide", do: "console-audit-badge-hidden", else: "console-audit-badge-shown")}><%= String.upcase(entry.action) %></span>
                    <span class="console-stat-label"><%= if entry.old_state, do: "ON", else: "OFF" %></span>
                  <% else %>
                    <%= if entry.action == "reset_all" do %>
                      <span class="console-audit-badge console-audit-badge-reset">RESET ALL</span>
                    <% else %>
                      <span class={"console-audit-badge " <> if(entry.old_state, do: "console-audit-badge-on", else: "console-audit-badge-off")}><%= if entry.old_state, do: "ON", else: "OFF" %></span>
                      <span class="console-audit-arrow">→</span>
                      <span class={"console-audit-badge " <> if(entry.new_state, do: "console-audit-badge-on", else: "console-audit-badge-off")}><%= if entry.new_state, do: "ON", else: "OFF" %></span>
                    <% end %>
                  <% end %>
                  <span class="console-audit-route"><%= entry.key %></span>
                </div>
                <span class="console-audit-time"><%= entry.timestamp %></span>
              </div>
            <% end %>
            <%= if @audit_offset < @audit_total do %>
              <button phx-click="load_more_audit" class="console-group-btn" style="margin-top:0.75rem;display:block;width:100%;text-align:center;">Load more (<%= @audit_total - @audit_offset %> remaining)</button>
            <% end %>
            <%= if @audit_entries == [] do %>
              <p class="console-stat-label" style="text-align:center;padding:1rem;">No audit entries yet.</p>
            <% end %>
          </div>
        <% end %>
      </div>

      <%= if @current_user.role == :admin do %>
        <div class="console-audit-panel">
          <button phx-click="toggle_accounts" class="console-audit-toggle">
            <span>👥 Accounts</span>
            <span><%= if @show_accounts, do: "▲", else: "▼" %></span>
          </button>
          <%= if @show_accounts do %>
            <div class="console-audit-body">
              <form phx-submit="add_account" style="display:flex;gap:0.5rem;margin-bottom:1rem;flex-wrap:wrap;">
                <input type="text" name="username" placeholder="Username" class="login-input" style="flex:1;min-width:120px;margin:0;" required>
                <input type="password" name="password" placeholder="Password" class="login-input" style="flex:1;min-width:120px;margin:0;" required>
                <select name="role" class="login-input" style="flex:0;min-width:100px;margin:0;">
                  <option value="viewer">Viewer</option>
                  <option value="admin">Admin</option>
                </select>
                <button type="submit" class="console-bulk-btn console-bulk-enable">Add</button>
              </form>
              <%= for account <- @account_list do %>
                <div class="console-audit-row">
                  <div class="console-audit-left">
                    <span class="console-method-badge"><%= if account.role == :admin, do: "Admin", else: "Viewer" %></span>
                    <span style="font-size:0.85rem;"><%= account.username %></span>
                    <span class="console-audit-time"><%= account.created_at %></span>
                  </div>
                  <%= if account.username != @current_user.username do %>
                    <button phx-click="delete_account" phx-value-username={account.username} class="console-bulk-btn console-bulk-disable" style="font-size:0.7rem;padding:0.2rem 0.5rem;">Remove</button>
                  <% end %>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
      <% end %>

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

    <%= if @show_plans_modal do %>
      <div class="console-modal-overlay">
        <div class="console-modal" phx-click-away="close_plans_modal" style="min-width:500px;">
          <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:1rem;">
            <h3 style="margin:0;">Compare Plans</h3>
            <button phx-click="close_plans_modal" style="border:none;background:none;cursor:pointer;font-size:1.2rem;color:inherit;">✕</button>
          </div>
          <table style="width:100%;border-collapse:collapse;font-size:0.85rem;">
            <thead>
              <tr style="border-bottom:1px solid #e5e7eb;">
                <th style="text-align:left;padding:0.5rem;">Feature</th>
                <th style={"text-align:center;padding:0.5rem;" <> if(License.get_tier() == :free, do: "color:#3b82f6;font-weight:700;", else: "")}>
                  Free
                  <%= if License.get_tier() == :free do %>
                    <svg style="display:inline;width:16px;height:16px;vertical-align:middle;margin-left:2px;" fill="none" stroke="#16a34a" stroke-width="2.5" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M5 13l4 4L19 7"/></svg>
                  <% end %>
                </th>
                <th style={"text-align:center;padding:0.5rem;" <> if(License.get_tier() == :paid, do: "color:#8b5cf6;font-weight:700;", else: "")}>
                  PRO
                  <%= if License.get_tier() == :paid do %>
                    <svg style="display:inline;width:16px;height:16px;vertical-align:middle;margin-left:2px;" fill="none" stroke="#16a34a" stroke-width="2.5" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M5 13l4 4L19 7"/></svg>
                  <% end %>
                </th>
              </tr>
            </thead>
            <tbody>
              <%= for item <- Features.comparison() do %>
                <tr style="border-bottom:1px solid #f1f5f9;">
                  <td style="padding:0.6rem 0.5rem;"><%= item.name %></td>
                  <td style={"text-align:center;padding:0.6rem 0.5rem;" <> if(License.get_tier() == :free, do: "font-weight:600;color:#16a34a;", else: "")}><%= item.free %></td>
                  <td style={"text-align:center;padding:0.6rem 0.5rem;" <> if(License.get_tier() == :paid, do: "font-weight:600;color:#16a34a;", else: "")}><%= item.paid %></td>
                </tr>
              <% end %>
            </tbody>
          </table>
          <p style="font-size:0.7rem;color:#9ca3af;margin-top:1rem;text-align:center;">
            <%= if License.get_tier() == :paid do %>
              ✅ You are on the <strong>PRO</strong> plan
            <% else %>
              You are on the <strong>Free</strong> plan — <button phx-click="close_plans_modal" style="color:#3b82f6;background:none;border:none;cursor:pointer;font-size:0.7rem;">upgrade to PRO</button>
            <% end %>
          </p>
        </div>
      </div>
    <% end %>

    <%= if @show_user_limit_popup do %>
      <div class="console-modal-overlay">
        <div class="console-modal" style="text-align:center;max-width:360px;">
          <h3 style="margin-top:0;">🔒 User Limit Reached</h3>
          <p style="font-size:0.85rem;color:#6b7280;">Free tier is limited to <%= Features.max_admins() %> users. Upgrade to PRO for unlimited accounts.</p>
          <div style="display:flex;gap:0.5rem;margin-top:1rem;justify-content:center;">
            <button phx-click="dismiss_user_limit_popup" class="console-group-btn">Dismiss</button>
            <button phx-click="show_plans_modal" class="console-bulk-btn console-bulk-enable">Upgrade to PRO</button>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  # --- helpers ---

  defp username(socket), do: socket.assigns.current_user.username
  defp is_admin?(socket), do: socket.assigns.current_user.role == :admin

  defp tier_label(:paid), do: "PRO"
  defp tier_label(:free), do: "FREE"

  defp tier_badge_style(:paid), do: "background:#dbeafe;color:#1e40af;"
  defp tier_badge_style(:free), do: "background:#e5e7eb;color:#374151;"

  defp upgrade_notice? do
    has_config = Application.get_env(:api_management_console, :app_name) ||
                 Application.get_env(:api_management_console, :hide_powered_by)
    has_config && not Features.enabled?(:company_branding)
  end

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

    log("[ApiConsole] search — query=#{inspect(query)}, groups=#{map_size(final)}, total=#{stats_for(final).total}")

    # Apply route cap for free tier
    {capped_groups, teaser_routes, over_cap} = apply_route_cap(final)

    socket
    |> assign(:filtered_routes, capped_groups)
    |> assign(:stats, stats_for(all_routes))
    |> assign(:teaser_routes, teaser_routes)
    |> assign(:routes_over_cap, over_cap)
  end

  defp apply_route_cap(groups) do
    # Sort groups alphabetically for deterministic ordering
    ordered_groups = Enum.sort_by(groups, fn {name, _} -> name end)

    case Features.max_routes() do
      :unlimited -> {groups, [], 0}
      cap ->
        # Flatten all mutable routes (preserving order within groups)
        all_routes =
          ordered_groups
          |> Enum.flat_map(fn {_group, routes} -> routes end)
          |> Enum.filter(& &1.mutable)

        total = length(all_routes)

        if total <= cap do
          {groups, [], 0}
        else
          # Routes 1..cap-3 → visible in groups
          # Routes cap-2..cap → teaser (blurred)
          # Routes cap+1..end → hidden entirely
          visible_count = max(cap - 3, 0)
          teaser_count = min(3, cap - visible_count)

          visible_keys =
            all_routes
            |> Enum.take(visible_count)
            |> Enum.map(& &1.key)
            |> MapSet.new()

          teaser_routes =
            all_routes
            |> Enum.drop(visible_count)
            |> Enum.take(teaser_count)

          over_cap = total - cap

          capped_groups =
            Map.new(groups, fn {group, routes} ->
              filtered =
                Enum.filter(routes, fn r ->
                  not r.mutable or MapSet.member?(visible_keys, r.key)
                end)

              {group, filtered}
            end)
            |> Enum.reject(fn {_, routes} -> routes == [] end)
            |> Map.new()

          {capped_groups, teaser_routes, over_cap}
        end
    end
  end

  defp stats_for(grouped_routes), do: compute_stats(grouped_routes)

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

  defp clear_selection(socket), do: assign(socket, :selected_keys, MapSet.new())

  defp mutable_keys(grouped_routes) do
    grouped_routes
    |> Map.values()
    |> List.flatten()
    |> Enum.filter(& &1.mutable)
    |> Enum.map(& &1.key)
  end
end
