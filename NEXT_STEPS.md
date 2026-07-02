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

## ✅ Phase 5 — Done

### 1. Free Tier Limits (Enforced)

- **50 route max** — visible cap with fade-to-lock teaser (last 3 routes blurred with lock overlay + upgrade CTA)
- **5 user max** — `Accounts.can_create?/0` gate + upgrade popup in UI
- **30-day audit cap** — retention filter in `AuditLog.Store.list/2` (applies to UI and CSV download)

### 2. Feature Comparison Modal

"Compare Plans" button next to tier badge → modal showing Free vs Paid feature matrix. Active plan highlighted with green checkmark and green feature values. Non-interactive modal body (only closes via ✕ or click-away).

---

## Phase 6 — Next Up

### 1. Concurrent Toggle Handling

If two users toggle the same endpoint simultaneously, the logs should reflect both actions deterministically. Currently CubDB writes are not atomic read-then-write — a race could lose intermediate state.

- **Fix:** Use CubDB transactions for toggle operations
- **Benefit:** Deterministic audit trail even under concurrent use, no lost state

### 2. Paid Features — Implement & Gate

Build the remaining paid-only features (currently commented out in `features.ex`):

- **`scheduled_toggles`** — schedule enable/disable at specific times (needs Oban integration, schedule UI, cron storage)
- **`postgresql_storage`** — PostgreSQL backend option via Ecto (needs schema, migration, Store adapter swap)
- **`slack_notifications`** — webhook alerts on policy changes (needs webhook config, HTTP client, templates)

### 3. Configurable Route Selection (Free Tier)

Currently the free tier caps at 50 routes and shows the first 47 as toggleable + 3 as faded teaser. This is fragile — if new routes are added or the route list order changes on refresh, the set of interactive routes shifts unpredictably.

- **Fix:** Let the user manually select which routes are "active" under the free tier cap. Store the selection in CubDB. Unselected routes show as immutable (greyed out) with an upgrade prompt.
- **Benefit:** Predictable, user-controlled list of managed routes that survives refreshes and route additions.
- **Files:** `route_console_live.ex`, `route_policies/store.ex`

---

## Upcoming (Complex — Later)

- **SSO Integration** — OIDC/SAML login via Okta, Azure AD, Google Workspace. Needed for enterprise sales but only worth building when paying Enterprise customers request it.
