defmodule ApiManagementConsoleV2.Branding do
  @moduledoc """
  Company branding configuration for the API Management Console.

  ## Configuration

      config :api_management_console, :branding,
        app_name: "Acme Corp API Console",
        primary_color: "#FF6B35",
        hide_powered_by: true
  """

  @defaults %{
    app_name: "API Management Console",
    primary_color: "#3b82f6",
    hide_powered_by: false
  }

  def config do
    Map.merge(@defaults, Application.get_env(:api_management_console, :branding, %{}))
  end

  def app_name, do: config().app_name
  def primary_color, do: config().primary_color
  def hide_powered_by?, do: config().hide_powered_by
end
