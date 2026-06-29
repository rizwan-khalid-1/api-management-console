# Next Steps

> Delete this file when the project is complete.

---

## ✅ Phase 1 — Done

1. Create the test app → verify everything works in LIVE mode
2. Build the health bar + counts → instant visual feedback
3. Add dark mode in console
4. Add protected route logic → grey out + prevent toggle
5. Improve overall layout → match the Cursor design

---

## ✅ Phase 2 — Done

1. Search & Filter — text input, `phx-keyup` with debounce, filters by path/method/controller
2. Audit Log — every toggle logged (who, what, when, old→new), expandable with pagination, CSV download
3. Bulk Select & Toggle — checkboxes, per-group select/clear, floating bulk action bar

---


## 🐛 Known Bugs

- **Toggle buttons don't work on static sites** — `<button phx-click>` requires LiveView WebSocket. Consumers without LiveView JS (`--no-assets` apps) get dead render with non-functional toggles.

---

## ✅ Phase 3 — Done

1. Hide Routes — checkbox select → Hide button in bulk bar, hidden count in header, clickable modal to show/restore, audit logged
2. Configurable storage path — `config :api_management_console, :storage_dir`
3. Reset All Policies — big red button with confirmation modal, audit logged
4. Company Branding — `config :api_management_console, :branding, app_name: "..."`, hide_powered_by, primary_color

---

## ✅ Phase 4 — Done

1. Replace DETS with CubDB — ACID transactions, crash-safe, concurrent reads, zero config
2. RBAC — Admin/Viewer roles, session-based login, account management, centralized admin guard
3. Licensing Module — offline JWT validation, trial support, scalable feature flags (Features.enabled?/1), FREE/PRO badge in header
4. CubDB Supervision — Supervisor with auto-restart on crash, zero downtime

## Phase 5 — Next Steps

### 1. Paid Features — Implement & Gate

Uncomment and build the remaining paid-only features:

- **`unlimited_routes`** — enforce 50-route cap on free tier, unlimited on paid
- **`scheduled_toggles`** — schedule enable/disable at specific times
- **`postgresql_storage`** — PostgreSQL backend option
- **`slack_notifications`** — webhook alerts on policy changes

### 2. Free Tier Limits (Enforce)

Add enforcement for existing free-tier caps:

- **50 route max** — show warning/inline prompt when approaching limit
- **5 user max** — prevent adding more than 5 accounts on free tier
- **30-day audit cap** — filter audit entries older than 30 days on free tier

---

## Upcoming (Complex — Later)

- Scheduled toggles
- PostgreSQL storage
- handle limited routes in free version

---

## Distant Future (Phase 5+)

- **SSO Integration** — OIDC/SAML login via Okta, Azure AD, Google Workspace. Needed for enterprise sales but only worth building when paying Enterprise customers request it.
