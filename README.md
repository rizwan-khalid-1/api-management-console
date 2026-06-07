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

```elixir
# 1. Add the dependency
def deps do
  [
    {:api_management_console_v2, "~> 0.1.0"}
  ]
end

# 2. Install
$ mix deps.get
$ mix api_console.install

# 3. Configure credentials
config :api_console,
  admin_username: System.fetch_env!("API_CONSOLE_ADMIN_USERNAME"),
  admin_password: System.fetch_env!("API_CONSOLE_ADMIN_PASSWORD")

# 4. Mount the console in your router
scope "/" do
  pipe_through :browser
  api_console "/admin/apis"
end

# 5. Start your server
$ mix phx.server
# Visit http://localhost:4000/admin/apis
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

- Elixir ~> 1.14
- Phoenix ~> 1.6 or ~> 1.7
- Erlang/OTP

---

## Documentation

Full documentation is available at [https://hexdocs.pm/api_management_console_v2](https://hexdocs.pm/api_management_console_v2).

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
