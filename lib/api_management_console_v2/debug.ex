defmodule ApiManagementConsoleV2.Debug do
  @moduledoc false

  @doc "Logs a debug message only if debug mode is enabled in config."
  defmacro log(message) do
    if Application.get_env(:api_management_console, :debug, false) do
      quote do
        require Logger
        Logger.debug(unquote(message))
      end
    else
      :ok
    end
  end
end
