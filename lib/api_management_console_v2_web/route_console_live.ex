defmodule ApiManagementConsoleV2Web.RouteConsoleLive do
  @moduledoc """
  LiveView dashboard for managing route availability.

  Works in both modes:

    • **Live** — if the consumer app loads LiveView's JavaScript,
      toggles happen instantly without page reloads.
    • **Dead render** — without JS, toggles work via query-param
      navigation (graceful page reload).

  Changes are persisted via `ApiManagementConsoleV2.RoutePolicies` (DETS).
  """

  use Phoenix.LiveView

  require Logger

  alias ApiManagementConsoleV2.RoutePolicies

  @impl true
  def mount(_params, _session, socket) do
    Logger.debug("[ApiConsole] mount — connected?=#{connected?(socket)}, router=#{inspect(socket.router)}")

    ensure_route_policies_started()

    socket =
      socket
      |> assign(:routes, [])
      |> assign(:policies, %{})
      |> assign(:connected, connected?(socket))

    {:ok, load_routes(socket)}
  end

  @impl true
  def handle_params(%{"toggle" => path}, uri, socket) do
    Logger.debug("[ApiConsole] toggle — path=#{path}")

    current = Map.get(socket.assigns.policies, path, true)
    RoutePolicies.set_enabled(path, not current)

    clean_path = URI.parse(uri).path

    {:noreply,
     socket
     |> load_routes()
     |> push_patch(to: clean_path, replace: true)}
  end

  def handle_params(_params, _uri, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <div style="font-family: system-ui, sans-serif; max-width: 900px; margin: 2rem auto; padding: 0 1rem;">
      <h1 style="font-size: 1.5rem; margin-bottom: 0.25rem;">
        API Management Console
        <span style={connection_badge_style(@connected)}>
          <%= if @connected, do: "LIVE", else: "STATIC" %>
        </span>
      </h1>
      <p style="color: #64748b; margin-bottom: 0.25rem; font-size: 0.9rem;">
        Toggle routes on or off. Disabled routes return <code style="background:#f1f5f9;padding:2px 6px;border-radius:4px;">403</code>.
      </p>
      <%= if not @connected do %>
        <p style="color: #b45309; margin-bottom: 1.5rem; font-size: 0.8rem; background: #fef3c7; padding: 0.5rem 0.75rem; border-radius: 6px;">
          💡 Toggles work but cause a page reload. For instant toggles, ensure your app loads LiveView&rsquo;s JavaScript client.
        </p>
      <% end %>

      <table style="width: 100%; border-collapse: collapse;">
        <thead>
          <tr style="text-align: left; border-bottom: 2px solid #e2e8f0;">
            <th style="padding: 0.5rem 0.75rem; font-size: 0.8rem; color: #64748b;">METHOD</th>
            <th style="padding: 0.5rem 0.75rem; font-size: 0.8rem; color: #64748b;">PATH</th>
            <th style="padding: 0.5rem 0.75rem; font-size: 0.8rem; color: #64748b;">CONTROLLER#ACTION</th>
            <th style="padding: 0.5rem 0.75rem; font-size: 0.8rem; color: #64748b; text-align: center;">ENABLED</th>
          </tr>
        </thead>
        <tbody>
          <%= for route <- @routes do %>
            <% enabled = Map.get(@policies, full_path(route), true) %>
            <tr style="border-bottom: 1px solid #f1f5f9;">
              <td style="padding: 0.5rem 0.75rem;">
                <span style={method_badge_style(route.method)}><%= route.method %></span>
              </td>
              <td style="padding: 0.5rem 0.75rem;">
                <code style="font-size: 0.85rem;"><%= route.path %></code>
              </td>
              <td style="padding: 0.5rem 0.75rem; color: #475569; font-size: 0.85rem;">
                <%= route.controller %>.<%= route.action %>
              </td>
              <td style="padding: 0.5rem 0.75rem; text-align: center;">
                <a
                  href={"?toggle=" <> URI.encode(full_path(route))}
                  style={"display:inline-block;text-decoration:none;" <> toggle_style(enabled)}
                >
                  <%= if enabled, do: "ON", else: "OFF" %>
                </a>
              </td>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>
    """
  end

  # --- helpers ---

  defp ensure_route_policies_started do
    case GenServer.start_link(RoutePolicies, [], name: RoutePolicies) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
      {:error, reason} -> raise "Failed to start RoutePolicies: #{inspect(reason)}"
    end
  end

  defp full_path(route), do: "#{route.method} #{route.path}"

  defp load_routes(socket) do
    router = socket.router
    routes = ApiManagementConsoleV2.list_routes(router)
    policies = RoutePolicies.all()

    Logger.debug("[ApiConsole] load_routes — count=#{length(routes)}, policies=#{map_size(policies)}")

    socket
    |> assign(:routes, routes)
    |> assign(:policies, policies)
  end

  defp connection_badge_style(true) do
    "background:#166534;color:#fff;padding:2px 8px;border-radius:4px;font-size:0.65rem;font-weight:600;margin-left:0.5rem;vertical-align:middle;"
  end

  defp connection_badge_style(false) do
    "background:#b45309;color:#fff;padding:2px 8px;border-radius:4px;font-size:0.65rem;font-weight:600;margin-left:0.5rem;vertical-align:middle;"
  end

  defp method_badge_style("GET"),    do: "background:#dbeafe;color:#1e40af;padding:2px 6px;border-radius:4px;font-size:0.75rem;font-weight:600;"
  defp method_badge_style("POST"),   do: "background:#dcfce7;color:#166534;padding:2px 6px;border-radius:4px;font-size:0.75rem;font-weight:600;"
  defp method_badge_style("PUT"),    do: "background:#fef9c3;color:#854d0e;padding:2px 6px;border-radius:4px;font-size:0.75rem;font-weight:600;"
  defp method_badge_style("PATCH"),  do: "background:#fef9c3;color:#854d0e;padding:2px 6px;border-radius:4px;font-size:0.75rem;font-weight:600;"
  defp method_badge_style("DELETE"), do: "background:#fee2e2;color:#991b1b;padding:2px 6px;border-radius:4px;font-size:0.75rem;font-weight:600;"
  defp method_badge_style(_),        do: "background:#f1f5f9;color:#475569;padding:2px 6px;border-radius:4px;font-size:0.75rem;font-weight:600;"

  defp toggle_style(true) do
    "background:#166534;color:#fff;padding:4px 12px;border-radius:6px;font-size:0.75rem;font-weight:600;cursor:pointer;min-width:48px;text-align:center;"
  end

  defp toggle_style(false) do
    "background:#991b1b;color:#fff;padding:4px 12px;border-radius:6px;font-size:0.75rem;font-weight:600;cursor:pointer;min-width:48px;text-align:center;"
  end
end
