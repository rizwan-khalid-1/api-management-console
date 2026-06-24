defmodule ApiManagementConsoleV2.Branding do
  @moduledoc """
  Company branding configuration for the API Management Console.

  Requires a paid license to use custom values.

  ## Configuration

      config :api_management_console,
        app_name: "Acme Corp API Console",
        hide_powered_by: true
  """

  alias ApiManagementConsoleV2.Features

  def app_name do
    if Features.enabled?(:company_branding) do
      Application.get_env(:api_management_console, :app_name, "API Management Console")
    else
      "API Management Console"
    end
  end

  def hide_powered_by? do
    if Features.enabled?(:company_branding) do
      Application.get_env(:api_management_console, :hide_powered_by, false)
    else
      false
    end
  end
end
