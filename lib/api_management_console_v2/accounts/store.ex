defmodule ApiManagementConsoleV2.Accounts.Store do
  @moduledoc false

  @db_name :api_accounts_db

  defp data_dir do
    dir = Application.get_env(:api_management_console, :storage_dir, "api-console-data")
    Path.join(dir, "api_accounts")
  end

  defp ensure_started do
    unless Process.whereis(@db_name) do
      CubDB.start_link(data_dir: data_dir(), name: @db_name)
    end
  end

  def start_link(_opts \\ []) do
    ensure_started()
  end

  def get(username) do
    ensure_started()
    case CubDB.get(@db_name, username) do
      nil -> nil
      account -> struct_from_map(account)
    end
  rescue
    _ -> nil
  end

  def put(account) do
    ensure_started()
    CubDB.put(@db_name, account.username, account)
    :ok
  end

  def delete(username) do
    ensure_started()
    CubDB.delete(@db_name, username)
    :ok
  end

  def all do
    ensure_started()
    CubDB.select(@db_name)
    |> Stream.map(fn {_k, v} -> struct_from_map(v) end)
    |> Enum.to_list()
  rescue
    _ -> []
  end

  defp struct_from_map(map) do
    %{
      username: map["username"] || map[:username],
      password_hash: map["password_hash"] || map[:password_hash],
      role: String.to_existing_atom(to_string(map["role"] || map[:role])),
      created_at: map["created_at"] || map[:created_at]
    }
  end
end
