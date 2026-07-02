# Roadmap

Public roadmap for the API Management Console library. See what's done, what's next, and where you can contribute.

---

## ✅ Completed

### Core Infrastructure
- Route discovery from Phoenix router
- One-click LiveView toggles (individual + group)
- Route guard plug (403 for disabled routes)
- CubDB storage — 3 databases (policies, audit, accounts) with Supervisor auto-restart
- Console route protection — immutable, untoggleable

### Dashboard UI
- Grouped routes by controller name, toggleable to flat view
- Health bar with enabled/disabled counts
- Search & filter by path, method, or controller
- Dark mode (auto `prefers-color-scheme`)
- Protected/immutable routes (greyed out, untoggleable) via config
- "STATIC" mode fallback — toggles work via query params without LiveView JS

### Bulk Operations
- Checkboxes, select all/clear per group
- Floating bulk action bar — enable, disable, hide
- Hide routes from console + restore modal
- Reset all policies with confirmation dialog

### Audit & Logging
- Every toggle/hide/reset logged (who, what, when, old→new)
- Expandable audit log with pagination
- CSV download
- 30-day retention on free tier, unlimited on paid

### Authentication & RBAC
- Session-based login (default: `admin` / `admin123`)
- Admin/Viewer roles with centralized admin guard
- Account management UI — add/remove users, change roles/passwords

### Licensing & Features
- Offline JWT license validation (RS256 + embedded public key)
- FREE/PRO tier badge in header
- Feature flag system (`Features.enabled?/1`)
- Company branding (paid-only, gated)
- Free tier limits enforced: 50 routes, 5 users, 30-day audit
- Fade-to-lock route limit teaser (last 3 routes blurred with lock overlay + upgrade CTA)
- Compare Plans modal with active plan highlighted

### Config
- Single config key (`config :api_management_console, ...`)
- Configurable storage path, debug logging, protected routes
- Customizable login template (`priv/templates/login.html.eex`)

---

## 🐛 Known Issues

- **Toggle buttons don't work on static sites** — `<button phx-click>` requires LiveView WebSocket. Consumers without LiveView JS (`--no-assets` apps) get dead render with non-functional toggles. Fallback via query params (page reload) works but isn't fully implemented for all actions.
### Storage
- CubDB transactions for all toggle mutations (atomic read+write, no lost state on concurrent toggles)

---

## 📅 Planned

### Paid Features — Implement & Gate
Build the remaining paid-only features (currently commented out in `features.ex`):

- **`scheduled_toggles`** — schedule enable/disable at specific times (needs Oban integration, schedule UI, cron storage)
- **`postgresql_storage`** — PostgreSQL backend option via Ecto (needs schema, migration, Store adapter swap)
- **`slack_notifications`** — webhook alerts on policy changes (needs webhook config, HTTP client, templates)

### Configurable Route Selection (Free Tier)
Let users manually pick which routes count toward their 50-route free tier cap. Store the selection in CubDB so it survives refreshes and new route additions.

---

## 🔮 Distant Future

- **SSO Integration** — OIDC/SAML login via Okta, Azure AD, Google Workspace
