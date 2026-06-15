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

## Phase 3 — Next Steps (easiest first)

### 1. Hide Routes / Groups from Console

Ability to hide specific routes or entire groups from the console view. Hidden routes are still enforced by the guard — they just don't appear in the UI.

- **Effort:** Low
- **Storage:** `hidden_routes` DETS table or app config
- **UI:** "Hide" button per route/group, "Show Hidden" toggle to reveal

### 2. Configurable DETS File Path

Let consumers specify where policy and audit DETS files are stored.

- **Effort:** Very Low
- **Config:** `config :api_management_console, dets_dir: "/var/data/api_console"`
- **Default:** `tmp/`

### 3. Reset All Policies

One-click button to re-enable ALL routes (clear the DETS table). Warns with confirmation.

- **Effort:** Very Low
- **UI:** Button in header card + confirm dialog
- **How:** Delete DETS file or iterate all keys → `Store.put(key, true)`

### 4. Refresh / Reload Routes

Button to re-scan the router for new/deleted routes without restarting.

- **Effort:** Very Low
- **How:** `handle_event("refresh")` → `load_dashboard(socket)` — already built

### 5. Company Branding

Let consumers customize the console's appearance — app name, logo, colors.

- **Effort:** Medium
- **Config:** `config :api_management_console, :branding, app_name: "Acme API Console", primary_color: "#FF6B35"`
- **UI:** Replace default title with `Branding.app_name()`, apply custom colors

---

## 🐛 Known Bugs

- **Toggle buttons don't work on static sites** — `<button phx-click>` requires LiveView WebSocket. Consumers without LiveView JS (`--no-assets` apps) get dead render with non-functional toggles.

---

## Upcoming (Complex — Later)

- Licensing module (JWT offline validation)
- RBAC (admin/viewer roles)
- Scheduled toggles
- PostgreSQL storage
- Company branding
- SSO integration
