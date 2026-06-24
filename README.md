# API Management Console

> **Turn 30 minutes of API disable/enable work into 5 seconds. One click. Instant effect. Full audit trail.**

A Phoenix LiveView library that gives you real-time control over your backend routes. Discover every endpoint in your Phoenix app, then enable or disable them from a protected dashboard — no redeployment needed.

---

## What It Does

- **Route Discovery** — Automatically pulls every route from your Phoenix router
- **Grouped Management** — Routes organized by namespace/module so you can toggle in bulk
- **One-Click Toggles** — Enable or disable individual routes or entire groups instantly
- **Guard Plug Enforcement** — Disabled routes return `403` at the Plug level, before they hit your controller
- **Persistent State** — Route policy stored locally via CubDB (embedded key-value store, crash-safe)
- **Protected Console** — Session-based login with admin/viewer roles, account management

---

## Why It Matters

| Scenario | Without Console | With Console |
|---|---|---|
| Emergency API shutdown | 30–60 min (find team, redeploy) | 5 seconds, one click |
| Peak traffic load shedding | SSH, edit configs, restart services | Dashboard on second monitor, instant |
| Security vulnerability exposure | 45 min (CI/CD + deploy) | Disable endpoint immediately |
| Maintenance window scheduling | Wake up at 2am or write custom scripts | Schedule it and sleep |
| Compliance (GDPR data freeze) | Days of discovery and code changes | One click to disable all tagged routes |

---

## Quick Start

### Prerequisites

Your Phoenix app must have LiveView's JavaScript client loaded. Every app created with `mix phx.new` ships with this in `assets/js/app.js`:

```js
import { Socket } from "phoenix"
import { LiveSocket } from "phoenix_live_view"

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, { params: { _csrf_token: csrfToken } })
liveSocket.connect()
```

If your app was scaffolded without this (e.g. `--no-assets`), you'll need to add it for live toggles. Without it, the console falls back to dead render only.

### Install

```elixir
# 1. Add the dependency (Git for now — Hex package coming soon)
def deps do
  [
    {:api_management_console, github: "rizwankhalid/api_management_console"}
  ]
end

# 2. Install
$ mix deps.get
```

### Mount the console in your router

**Option A — Use the `api_console` macro (quickest)**

```elixir
# In your router — `use` injects the route guard + auth pipeline automatically.
use ApiManagementConsoleV2.Router

scope "/" do
  pipe_through [:browser, :route_guard]
  api_console "/admin/api-console"
end
```

That's it. The `use` macro automatically:
- Defines `:route_guard` pipeline — blocks disabled routes (403)
- Defines the `:api_console_auth` pipeline (Basic Auth)
- Imports the `api_console` macro

**To enforce disabled routes**, add `:route_guard` to **every scope** you want protected — including API and browser routes, not just the console:

```elixir
scope "/", SampleBlogWeb do
  pipe_through [:browser, :route_guard]
  get "/", PageController, :index
end

scope "/api", SampleBlogWeb do
  pipe_through [:api, :route_guard]
  get "/blogs", BlogController, :index
end
```

Or add the plug directly inside each pipeline:

```elixir
pipeline :api do
  plug ApiManagementConsoleV2.Plugs.RouteGuard
end
```

The console uses session-based authentication. A default admin account is created on first use:

- **Username:** `admin`
- **Password:** `admin123`

Override via env vars:

```bash
export API_CONSOLE_ADMIN_USERNAME=admin
export API_CONSOLE_ADMIN_PASSWORD=your_password
```

### Configuration

All settings under a single config key:

```elixir
config :api_management_console,
  # Protected routes — cannot be toggled (supports strings and regex)
  protected_routes: [
    "/dev/dashboard",
    ~r{HealthController},
    ~r{^/api/internal/}
  ],

  # Storage path (default: "api-console-data/")
  storage_dir: "/var/data/api_console",

  # Company branding
  app_name: "Acme Corp API Console",
  hide_powered_by: true,

  # Debug logging (default: false)
  debug: true
```

**License key** — unlock paid features (offline JWT validation):

```bash
export API_CONSOLE_LICENSE_KEY=eyJhbGciOiJSUzI1NiIs...
```

**Option B — Add routes manually (full control)**

```elixir
# In your router — wire it up yourself
import Phoenix.LiveView.Router, only: [live: 3]

pipeline :route_guard do
  plug ApiManagementConsoleV2.Plugs.RouteGuard
end

scope "/admin/api-console" do
  pipe_through [:browser, :route_guard]
  plug ApiManagementConsoleV2Web.Plugs.RequireAdmin

  live "/", ApiManagementConsoleV2Web.RouteConsoleLive, :index
end
```

**Start your server:**
```bash
$ mix phx.server
# Visit http://localhost:4000/admin/api-console
```

---

## Features

### Free
- **Route Discovery** — auto-discovers all routes from Phoenix router
- **One-Click Toggles** — enable/disable individual routes or entire groups (up to 50 routes)
- **Route Guard** — blocks disabled routes with 403 at the Plug level
- **Session Login** — session-based authentication with admin/viewer roles
- **CubDB Storage** — embedded key-value store, crash-safe, ACID transactions
- **Grouped Routes** — routes organized by controller name, toggleable to flat view
- **Search & Filter** — instant search by path, method, or controller name
- **Health Bar** — visual progress bar showing enabled vs disabled ratio
- **Protected Routes** — immutable routes (greyed out, untoggleable) via config
- **Dark Mode** — auto-detects `prefers-color-scheme`
- **Bulk Operations** — checkboxes, select all/clear per group, bulk enable/disable
- **Hide Routes** — hide routes from the console view
- **Audit Log** — every action logged, expandable with pagination, 30-day history
- **Reset All** — one-click re-enable all routes with confirmation dialog
- **RBAC** — Admin and Viewer roles, up to 5 users (1 admin + 4 viewers)

### Paid
- **Unlimited Routes** — no 50-route cap *(coming soon)*
- **Unlimited Users** — no 5-user cap on RBAC *(coming soon)*
- **Full Audit History** — no 30-day retention limit, CSV download *(coming soon)*
- **Company Branding** — custom app name, hide powered-by footer ✅
- **Scheduled Toggles** — schedule enable/disable at specific times *(coming soon)*
- **PostgreSQL Storage** — multi-node consistency *(coming soon)*
- **Slack Notifications** — alerts on policy changes *(coming soon)*

---

## Storage Options

| Storage | Use Case | Tier |
|---|---|---|
| CubDB | Default — embedded, zero config, crash-safe | Free |
| PostgreSQL | Multi-node consistency, team environments | Paid |

---

## How Licensing Works

Offline validation via signed JWT tokens — no phone-home, no external server dependency:

1. Purchase a license
2. Receive your license key by email (signed JWT with embedded tier, expiry, trial claims)
3. Set `API_CONSOLE_LICENSE_KEY` in your environment
4. Paid features unlock automatically based on the license tier

Free tier is always available without a key.

---

## Requirements

- Elixir ~> 1.13
- Phoenix ~> 1.6 or ~> 1.7
- Erlang/OTP

---

## Documentation

Documentation is available in the `lib/` source and will be published to HexDocs once the package ships.

---

## License

- **Free Tier**: MIT License — use, modify, distribute freely
- **Paid Tier**: Commercial license — requires a valid license key (set `API_CONSOLE_LICENSE_KEY`)

---

## Community

- [GitHub Issues](https://github.com/rizwankhalid/api_management_console) — Bug reports & feature requests
- Discussions — Coming soon

---

*Built with ❤️ in Elixir for the Phoenix ecosystem.*
