defmodule ApiManagementConsoleV2.Accounts.Store do
  @moduledoc false

  @db_name :api_accounts_db

  def get(username) do
    case CubDB.get(@db_name, username) do
      nil -> nil
      account -> struct_from_map(account)
    end
  rescue
    _ -> nil
  end

  def put(account) do
    CubDB.put(@db_name, account.username, account)
    :ok
  end

  def delete(username) do
    CubDB.delete(@db_name, username)
    :ok
  end

  def all do
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
