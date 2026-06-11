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

## 🐛 Known Bugs

- **Toggle buttons don't work on static sites** — `<button phx-click>` requires LiveView WebSocket. Consumers without LiveView JS (`--no-assets` apps) get dead render with non-functional toggles. Need a `<a href>` query-param fallback or dual-mode toggle.

---

## Phase 2 — Simpler Next Steps (easiest first)

### 1. Search & Filter

Text input above route groups that filters by path, method, or controller name — client-side only.

- **Effort:** Very Low
- **How:** `handle_event("search", ...)` + `Enum.filter` on `@grouped_routes`, no storage needed

### 2. Audit Log

Append every toggle to a log (`who`, `what`, `when`, `old_state`, `new_state`), displayed at bottom of console.

- **Effort:** Low
- **How:** Append to a text file or separate DETS table, read-only `<details>` section at page bottom

### 3. Export Config

Download current route policies as a JSON file.

- **Effort:** Medium
- **How:** `RoutePolicies.Store.all()` → JSON encode → `Plug.Conn.send_download` via a controller route

### 4. Bulk Select & Toggle

Checkbox per route, "Select All" / "Deselect All", bulk ON/OFF button.

- **Effort:** Medium
- **How:** Checkbox UI + `handle_event("bulk_toggle", ...)` + `Store.bulk_put` (already built)

---

## Upcoming (Complex — Later)

- Licensing module (JWT offline validation)
- RBAC (admin/viewer roles)
- Scheduled toggles
- PostgreSQL storage
- Company branding
- SSO integration
