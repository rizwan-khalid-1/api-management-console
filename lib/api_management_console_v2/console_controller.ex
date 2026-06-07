defmodule ApiManagementConsoleV2.ConsoleController do
  @moduledoc false

  use Phoenix.Controller, formats: [:html]

  @doc """
  Placeholder dashboard — renders a list of discovered routes.

  Replace with a LiveView dashboard in a future release.
  """
  def index(conn, _params) do
    router = conn.private.phoenix_router

    routes =
      router
      |> ApiManagementConsoleV2.list_routes()
      |> Enum.map(fn r ->
        "<li><code>#{r.method} #{r.path}</code> → #{r.controller}</li>"
      end)
      |> Enum.join("\n")

    html(conn, """
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="utf-8">
      <title>API Management Console</title>
      <style>
        body { font-family: system-ui, sans-serif; max-width: 900px; margin: 2rem auto; padding: 0 1rem; }
        code { background: #f1f5f9; padding: 2px 6px; border-radius: 4px; font-size: 0.9em; }
        li { margin: 0.5rem 0; }
        h1 { font-size: 1.5rem; }
      </style>
    </head>
    <body>
      <h1>API Management Console</h1>
      <p>Routes discovered in <code>#{inspect(router)}</code>:</p>
      <ul>
        #{routes}
      </ul>
    </body>
    </html>
    """)
  end
end
