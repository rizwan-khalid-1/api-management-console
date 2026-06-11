# API Management Console

> **Turn 30 minutes of API disable/enable work into 5 seconds. One click. Instant effect. Full audit trail.**

A Phoenix LiveView library that gives you real-time control over your backend routes. Discover every endpoint in your Phoenix app, then enable or disable them from a protected dashboard — no redeployment needed.

---

## What It Does

- **Route Discovery** — Automatically pulls every route from your Phoenix router
- **Grouped Management** — Routes organized by namespace/module so you can toggle in bulk
- **One-Click Toggles** — Enable or disable individual routes or entire groups instantly
- **Guard Plug Enforcement** — Disabled routes return `403` at the Plug level, before they hit your controller
- **Persistent State** — Route policy stored locally via DETS (swap to PostgreSQL or Redis for multi-node)
- **Protected Console** — Admin dashboard behind Basic Auth so only you can make changes

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

The macro automatically adds HTTP Basic Auth. Set credentials:

```bash
export API_CONSOLE_ADMIN_USERNAME=admin
export API_CONSOLE_ADMIN_PASSWORD=your_password
```

### Configuration

**Protected (immutable) routes** — routes that cannot be toggled, shown grayed out in the console. The console's own path is automatically protected.

Add your own in `config/config.exs`. Supports two match types:

```elixir
config :api_management_console,
  protected_routes: [
    # String — matches path prefix or suffix
    "/dev/dashboard",

    # Regex — matches path AND controller module name
    ~r{HealthController},
    ~r{^/api/internal/}
  ]
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

### Free (Always)
- Auto-discover routes from any Phoenix router
- Enable/disable individual routes and groups
- DETS-backed persistent storage
- Guard Plug — 403 for disabled routes
- Admin Basic Auth (single user)
- Up to 25 routes

### Pro (Licensed)
- Unlimited routes
- Search, filter, and bulk operations
- Up to 5 admin accounts with RBAC (Admin/Viewer)
- Company branding (custom logo, colors, app name)
- Scheduled toggles for maintenance windows
- JSON/YAML export/import
- Slack and webhook alerts
- PostgreSQL support for multi-node consistency

### Enterprise (Licensed)
- Unlimited admins
- Full audit trail (2+ years)
- REST API for programmatic policy management (CI/CD integration)
- SSO (OIDC/SAML)
- White-label (remove all API Console branding)
- Redis storage for high-performance caching
- Policy versioning with rollback
- 99.9% SLA and priority support

---

## Storage Options

| Storage | Use Case | Tier |
|---|---|---|
| DETS | Default — single node, zero config | Free |
| PostgreSQL | Multi-node consistency, team environments | Pro |
| Redis | High performance, caching layer | Enterprise |

---

## How Licensing Works

Offline validation via signed JWT tokens — no phone-home, no external server dependency:

1. Purchase a license through Paddle or Lemon Squeezy
2. Receive your license key by email
3. Set `API_CONSOLE_LICENSE_KEY` in your environment
4. Premium features unlock automatically based on your tier

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
- **Pro & Enterprise**: Commercial license — requires a valid license key

---

## Community

- [GitHub Issues](https://github.com/rizwankhalid/api_management_console) — Bug reports & feature requests
- Discussions — Coming soon

---

*Built with ❤️ in Elixir for the Phoenix ecosystem.*
