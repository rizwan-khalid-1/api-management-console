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

## Phase 5 — Next Steps

### 1. Licensing Module (Offline JWT)

Add license key validation using signed JWT tokens. No phone-home, no external server.

- **Flow:** User sets `API_CONSOLE_LICENSE_KEY` env var → library validates signature with embedded public key → unlocks tier features
- **Tiers:** `:free`, `:pro`, `:enterprise`
- **Files:** `license.ex`, `features.ex`, `priv/keys/public_key.pem`
- **Dep:** `joken` (~> 2.6)
- **Effort:** Medium

### 3. RBAC (Admin / Viewer)

Multiple admin accounts with role-based access control.

- **Admin:** Full access — toggle routes, hide/show, reset, view audit
- **Viewer:** Read-only — can view routes and audit log, cannot toggle or change anything
- **Storage:** Credentials stored in a configurable file or `api_admins.dets`/CubDB
- **UI:** Login page (replace Basic Auth), role badge in header, disabled buttons for viewers
- **Effort:** High

---

## Upcoming (Complex — Later)

- Scheduled toggles
- PostgreSQL storage

---

## Distant Future (Phase 5+)

- **SSO Integration** — OIDC/SAML login via Okta, Azure AD, Google Workspace. Needed for enterprise sales but only worth building when paying Enterprise customers request it.
