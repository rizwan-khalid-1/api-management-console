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

### Configurable Route Selection (Free Tier)
- Admin picks up to 50 routes to manage from the "Manage Selection" modal
- Selected routes are interactive; unselected routes show as immutable + upgrade teaser
- Selection persists in CubDB, survives refreshes and resets
- Auto-seeds first 50 routes on first use (backward compatible)
- PRO tier: all routes managed, modal shows greyed-out ∞ indicator

### Config
- Single config key (`config :api_management_console, ...`)
- Configurable storage path, debug logging, protected routes
- Customizable login template (`priv/templates/login.html.eex`)

### Dead Render (Non-LiveView) Mode
- Full static HTML fallback for apps without LiveView JS
- Every feature works: toggles, search, audit log, account management, compare plans, reset
- Bulk checkboxes/select hidden in dead mode (requires JavaScript)

### Storage
- CubDB transactions for all toggle mutations (atomic read+write, no lost state on concurrent toggles)

---

## 🐛 Known Issues

- **Bulk operations require LiveView** — checkboxes and bulk bar only work with LiveView JS. Dead render mode hides these features.
- **LiveView JS required for instant toggles** — without it, toggles reload the page (still functional, just not instant).

---

## 📅 Planned

### Paid Features (Not Yet Implemented)

Features registered as `:paid` in `features.ex` but not yet built:

| Feature | Description | Status |
|---|---|---|
| Scheduled Toggles | Schedule enable/disable at specific times (needs Oban, schedule UI, cron storage) | 🔜 Planned |
| PostgreSQL Storage | Multi-node Ecto backend (needs schema, migration, Store adapter swap) | 🔜 Planned |
| Slack Notifications | Webhook alerts on policy changes (needs webhook config, HTTP client, templates) | 🔜 Planned |

---

## 🔮 Distant Future

- **SSO Integration** — OIDC/SAML login via Okta, Azure AD, Google Workspace
