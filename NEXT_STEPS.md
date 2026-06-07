# Next Steps

> Delete this file when the project is complete.

---

## 1. Create a proper test app

```bash
mix phx.new api_console_test --no-ecto
cd api_console_test
```

Add the api_console dep (`:path` or `:github`), then `use ApiManagementConsoleV2.Router` and mount the dashboard. This gives a clean environment to test:

- LIVE mode (real LiveView JS)
- Real routes to toggle
- Route guard enforcement

## 2. Improve the dashboard layout

The layout [Cursor generated earlier](https://cursor.com) was well-received. It had:

- A **health bar** at the top showing the ratio of enabled vs disabled APIs
- Clean table layout with grouped routes
- Professional visual hierarchy

Replace the current inline-styled table with the Cursor layout (or rebuild to match it).

## 3. Add dark mode

Show dark mode by default. Either:

- Read `prefers-color-scheme` and apply dark automatically
- Or hardcode dark theme colors in the inline styles

Colors to reference:
```
Background: #0f172a (slate-900)
Card/Table:  #1e293b (slate-800)
Text:        #e2e8f0 (slate-200)
Accent:      #3b82f6 (blue-500)
```

## 4. Show enabled / disabled counts at the top

Above the route table, display summary stats:

```
🟢 458 enabled   🔴 15 disabled
```

Or a visual health bar showing the ratio. This gives instant visibility into the system state.

## 5. Protect admin / system routes from toggling

Some routes should never be disabled (e.g., the console itself, health checks, admin endpoints). These should be:

- **Greyed out** in the UI (visually distinguishable)
- **Untoggleable** — clicking does nothing
- Filtered by a configurable pattern (e.g., paths starting with `/admin/` or containing `HealthController`)

```elixir
config :api_management_console,
  protected_routes: [
    ~r{^/admin/},
    ~r{HealthController}
  ]
```

---

## Order of work

1. Create the test app → verify everything works in LIVE mode
2. Build the health bar + counts → instant visual feedback
3. Add dark mode in console
4. Add protected route logic → grey out + prevent toggle
5. Improve overall layout → match the Cursor design
