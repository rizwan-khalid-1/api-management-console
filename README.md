# API Management Console [![Hex Version](https://img.shields.io/hexpm/v/api_management_console.svg)](https://hex.pm/packages/api_management_console) [![Hex Docs](https://img.shields.io/badge/docs-hexpm-blue.svg)](https://hexdocs.pm/api_management_console)

> **Turn 30 minutes of API disable/enable work into 5 seconds. One click. Instant effect. Full audit trail.**

A Phoenix library that gives you real-time control over your backend routes. Discover every endpoint in your Phoenix app, then enable or disable them from a protected dashboard — no redeployment needed.

---

## What It Does

- **Route Discovery** — Automatically pulls every route from your Phoenix router
- **Grouped Management** — Routes organized by controller name so you can toggle in bulk
- **One-Click Toggles** — Enable or disable individual routes or entire groups instantly via LiveView (page reload fallback for apps without LiveView JS)
- **Route Guard Plug** — Disabled routes return `403` at the Plug level, before they hit your controller
- **Session-Based Login** — Secure login page with admin/viewer role-based access control
- **Account Management** — Add/remove users, set roles (admin/viewer) directly from the dashboard
- **Persistent State** — Route policies, accounts, and audit logs stored via CubDB (crash-safe, ACID atomic toggles)
- **Audit Log** — Every toggle, hide, and account change logged with who/what/when — expandable with pagination and CSV download
- **Dead Render Fallback** — Full static HTML fallback for API-only apps without LiveView JS

---

## Why It Matters

| Scenario | Without Console | With Console |
|---|---|---|
| Emergency API shutdown | 30–60 min (find team, redeploy) | 5 seconds, one click |
| Peak traffic load shedding | SSH, edit configs, restart services | Dashboard on second monitor, instant |
| Security vulnerability exposure | 45 min (CI/CD + deploy) | Disable endpoint immediately |
| Maintenance window | Wake up at 2am or write custom scripts | Toggle it and sleep |

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

**Without LiveView JS** (`--no-assets` or API-only apps): the console operates in **dead-render mode** using standard HTML forms and links. Every feature works: toggles, search, audit log expand, account management, compare plans modal, reset all. Features that require JavaScript (bulk checkboxes/select) are hidden in dead mode.

### Install

The package can be installed by adding `api_management_console` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:api_management_console, "~> 0.1.0"}
  ]
end
```

Or from GitHub:

```elixir
{:api_management_console, github: "rizwan-khalid-1/api-management-console"}
```

### Mount the console in your router

```elixir
# In your router — `use` injects route guard + auth pipelines automatically
use ApiManagementConsoleV2.Router

scope "/" do
  pipe_through [:browser, :route_guard]
  api_console "/admin/api-console"
end
```

That's it. The `use` macro automatically:
- Defines the `:route_guard` pipeline — blocks disabled routes with `403`
- Defines the `:api_console_auth` pipeline — session-based login protection
- Registers the `api_console/1` macro to mount dashboard routes under your chosen path

**To enforce disabled routes**, add `:route_guard` to **every scope** you want protected:

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

Or add the plug directly inside any pipeline:

```elixir
pipeline :api do
  plug ApiManagementConsoleV2.Plugs.RouteGuard
end
```

### Default login

The console uses session-based authentication. A default admin account is auto-created on first access:

- **Username:** `admin`
- **Password:** `admin123`

Override via env vars:

```bash
export API_CONSOLE_ADMIN_USERNAME=admin
export API_CONSOLE_ADMIN_PASSWORD=your_password
```

---

## Configuration

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

  # Company branding (requires paid license — see Licensing below)
  app_name: "Acme Corp API Console",
  hide_powered_by: true,

  # Debug logging (default: false)
  debug: true,

  # License key — unlock paid features (offline JWT validation)
  license_key: "eyJhbGciOiJSUzI1NiIs..."
```

Or set the license key via environment variable:

```bash
export API_CONSOLE_LICENSE_KEY=eyJhbGciOiJSUzI1NiIs...
```

### Manual route setup (no macro)

```elixir
# Wire it up yourself instead of using `api_console`
scope "/admin/api-console" do
  pipe_through [:browser]

  # Login routes (unauthenticated)
  get "/login", ApiManagementConsoleV2Web.LoginController, :index
  post "/login", ApiManagementConsoleV2Web.LoginController, :create

  # Protected console routes
  pipe_through [:api_console_auth]
  get "/logout", ApiManagementConsoleV2Web.Plugs.Logout, []
  get "/audit.csv", ApiManagementConsoleV2Web.Plugs.AuditDownload, []
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

### Free Tier

| Feature | Description |
|---|---|
| Route Discovery | Auto-discovers all routes from your Phoenix router |
| One-Click Toggles | Enable/disable individual routes or entire groups — instant via LiveView, page reload in dead mode |
| Dead Render Fallback | Full static HTML fallback for apps without LiveView JS |
| Route Guard | Blocks disabled routes with `403` at the Plug level |
| Session Login | Secure login page with session-based authentication |
| RBAC | Admin and Viewer roles — admins toggle, viewers read-only |
| Account Management | Add/remove users, change roles, up to 5 users |
| CubDB Storage | Embedded key-value store — crash-safe, ACID atomic toggles |
| Grouped Routes | Routes organized by controller name, toggleable to flat view |
| Search & Filter | Search by path, method, or controller name |
| Health Bar | Visual progress bar showing enabled vs disabled ratio |
| Protected Routes | Immutable routes (greyed out, untoggleable) via config |
| Dark Mode | Auto-detects `prefers-color-scheme` |
| Bulk Operations | Checkboxes, select all/clear per group, bulk enable/disable/hide *(LiveView only)* |
| Hide Routes | Hide routes from console view, restore from modal |
| Audit Log | Every action logged with username, expandable with pagination, CSV download |
| 30-Day Audit History | Free tier retains 30 days of audit entries |
| 50-Route Limit | Free tier manages up to 50 routes — extras shown as faded teaser with upgrade CTA |

### Paid (PRO) Tier

| Feature | Description | Status |
|---|---|---|
| Company Branding | Custom app name, hide "Powered by" footer | ✅ Done |
| Unlimited Routes | No 50-route cap | ✅ Done |
| Unlimited Users | No 5-user cap on RBAC | ✅ Done |
| Full Audit History | No 30-day retention limit | ✅ Done |
| Scheduled Toggles | Schedule enable/disable at specific times | 🔜 Planned |
| PostgreSQL Storage | Multi-node consistency via Ecto | 🔜 Planned |
| Slack Notifications | Webhook alerts on policy changes | 🔜 Planned |

---

## Route Limit (Free Tier)

When your app has more than 50 managed routes on the free tier:

- **Routes 1–47** render normally — fully interactive
- **Routes 48–50** appear in a **faded teaser container** below the groups:
  - Dimmed, non-interactive, with a gradient blur overlay
  - Lock icon + "X routes hidden" + "Upgrade to PRO" button
- **Routes 51+** are hidden entirely

The "Compare Plans" modal (button next to the tier badge) shows exactly what each tier includes, with the active plan highlighted in green.

---

## Storage

| Storage | Use Case | Status |
|---|---|---|
| CubDB | Default — embedded, zero config, crash-safe, ACID transactions | ✅ Free |
| PostgreSQL | Multi-node consistency, team environments | Planned (paid) |

---

## How Licensing Works

Offline JWT validation — no phone-home, no external server dependency.

1. Receive your license key (signed JWT with embedded tier, expiry, trial claims)
2. Set `API_CONSOLE_LICENSE_KEY` env var or `license_key` in config
3. Paid features unlock automatically based on the license tier

No license key = Free tier. All paid features degrade gracefully — limits are enforced, upgrade prompts appear where applicable.

License keys are issued by the library maintainer. Contact the author to obtain a key for your organization.

---

## Requirements

- Elixir ~> 1.13
- Phoenix ~> 1.6, ~> 1.7, or ~> 1.8
- Erlang/OTP

---

## Dependencies

| Dependency | Purpose |
|---|---|
| `cubdb` (~> 2.0) | Embedded key-value store for policies, accounts, audit logs |
| `bcrypt_elixir` (~> 3.0) | Password hashing for account management |
| `joken` (~> 2.6) | JWT verification for offline license validation |
| `phoenix` (optional) | Web framework integration |
| `phoenix_live_view` (optional) | Real-time dashboard UI |

---

## Screenshots

### Main Dashboard (LiveView)
![Main Dashboard](https://raw.githubusercontent.com/rizwan-khalid-1/api-management-console/main/screenshots/main-dashboard-view.png)

### Main Dashboard (Static / Dead Render)
![Main Dashboard Static](https://raw.githubusercontent.com/rizwan-khalid-1/api-management-console/main/screenshots/main-dashboard-view-static-app.png)

### Routes with Bulk Selection
![Routes Checked](https://raw.githubusercontent.com/rizwan-khalid-1/api-management-console/main/screenshots/routes-checked.png)

### Audit Log & Account Management
![Audit Log & Accounts](https://raw.githubusercontent.com/rizwan-khalid-1/api-management-console/main/screenshots/audit-log+accounts-section.png)

### Compare Plans Modal
![Compare Plans](https://raw.githubusercontent.com/rizwan-khalid-1/api-management-console/main/screenshots/compare-plans-modal.png)

### Login Screen
![Login](https://raw.githubusercontent.com/rizwan-khalid-1/api-management-console/main/screenshots/login-screen.png)

---

## Roadmap

See [ROADMAP.md](https://github.com/rizwan-khalid-1/api-management-console/blob/main/ROADMAP.md) for completed features, planned work, and known issues.

---

## License

MIT License — use, modify, distribute freely. Paid features are unlocked via a signed JWT license key, not a separate software license.

---

## Community

- [GitHub Issues](https://github.com/rizwan-khalid-1/api-management-console/issues) — Bug reports & feature requests

---

*Built with ❤️ in Elixir for the Phoenix ecosystem.*
