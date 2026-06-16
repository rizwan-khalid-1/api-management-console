defmodule ApiManagementConsoleV2.ConsolePaths do
  @moduledoc false

  @table_name :api_console_paths
  @env_key :__console_paths__

  def init do
    unless :ets.whereis(@table_name) != :undefined do
      :ets.new(@table_name, [:set, :public, :named_table])

      # Re-populate from Application env (survives compile-process death)
      Application.get_env(:api_management_console, @env_key, [])
      |> Enum.each(fn path -> :ets.insert(@table_name, {path, true}) end)
    end

    :ok
  end

  def add(path) do
    init()
    :ets.insert(@table_name, {path, true})

    # Persist in Application env as backup for restarts
    existing = Application.get_env(:api_management_console, @env_key, [])
    unless path in existing do
      Application.put_env(:api_management_console, @env_key, [path | existing])
    end

    :ok
  end

  def matches?(request_path) do
    init()

    :ets.match(@table_name, {:"$1", :_})
    |> List.flatten()
    |> Enum.any?(fn prefix ->
      String.starts_with?(request_path, prefix) or String.ends_with?(request_path, prefix)
    end)
  end
end
