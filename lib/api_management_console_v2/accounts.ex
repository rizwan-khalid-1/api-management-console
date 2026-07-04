defmodule ApiManagementConsoleV2.Accounts do
  @moduledoc """
  User account management with role-based access control.

  Accounts are stored in CubDB alongside policies and audit logs.
  Passwords are hashed with bcrypt_elixir.

  ## Roles

    • `:admin`  — full access: toggle, hide, reset, manage accounts
    • `:viewer` — read-only: view routes and audit log, no mutations

  ## Default account

  On first use, if no accounts exist, a default admin is auto-created:
  username `"admin"`, password `"admin123"`.
  Override via env vars: `API_CONSOLE_ADMIN_USERNAME` / `API_CONSOLE_ADMIN_PASSWORD`.

  ## Session

  After login, the username and role are stored in Plug session:
  `:api_console_user` → `%{username: "john", role: :admin}`
  """

  alias ApiManagementConsoleV2.Accounts.Store
  alias ApiManagementConsoleV2.Features

  @valid_roles [:admin, :viewer]

  @doc "Returns the list of valid roles."
  def valid_roles, do: @valid_roles

  @doc "Parses a role string into an atom. Returns :viewer for unknown values."
  def parse_role("admin"), do: :admin
  def parse_role("viewer"), do: :viewer
  def parse_role(role) when is_atom(role) and role in @valid_roles, do: role
  def parse_role(_), do: :viewer

  @doc "Authenticate a user. Returns {:ok, role} or {:error, reason}."
  def authenticate(username, password) when is_binary(username) and is_binary(password) do
    case Store.get(username) do
      nil ->
        Bcrypt.no_user_verify()
        {:error, :invalid_credentials}

      account ->
        if Bcrypt.verify_pass(password, account.password_hash) do
          {:ok, account.role}
        else
          {:error, :invalid_credentials}
        end
    end
  end

  @doc "Create a new account. Returns :ok or {:error, reason}."
  def create(username, password, role \\ :viewer)

  def create(username, password, role) when is_binary(username) and is_binary(password) do
    if Store.get(username) do
      {:error, :already_exists}
    else
      hash = Bcrypt.hash_pwd_salt(password)
      account = %{
        username: username,
        password_hash: hash,
        role: role,
        created_at: DateTime.utc_now() |> DateTime.to_iso8601()
      }
      Store.put(account)
      :ok
    end
  end

  @doc "Delete an account. Cannot delete the last admin."
  def delete(username) when is_binary(username) do
    account = Store.get(username)

    cond do
      is_nil(account) ->
        {:error, :not_found}

      account.role == :admin and count_admins() <= 1 ->
        {:error, :last_admin}

      true ->
        Store.delete(username)
        :ok
    end
  end

  @doc "List all accounts."
  def list, do: Store.all()

  @doc "Change a user's role."
  def set_role(username, role) when role in [:admin, :viewer] do
    case Store.get(username) do
      nil -> {:error, :not_found}
      account ->
        Store.put(%{account | role: role})
        :ok
    end
  end

  @doc "Change a user's password."
  def change_password(username, new_password) when is_binary(new_password) do
    case Store.get(username) do
      nil -> {:error, :not_found}
      account ->
        hash = Bcrypt.hash_pwd_salt(new_password)
        Store.put(%{account | password_hash: hash})
        :ok
    end
  end

  @doc "Ensure at least one admin exists. Creates default if none."
  def ensure_admin_exists do
    if count_admins() == 0 do
      default_username = System.get_env("API_CONSOLE_ADMIN_USERNAME", "admin")
      default_password = System.get_env("API_CONSOLE_ADMIN_PASSWORD", "admin123")
      create(default_username, default_password, :admin)
    end
  end

  @doc "Count admin accounts."
  def count_admins do
    Store.all()
    |> Enum.count(&(&1.role == :admin))
  end

  @doc "Returns true if a new account can be created (within tier limit)."
  def can_create? do
    case Features.max_admins() do
      :unlimited -> true
      max -> length(Store.all()) < max
    end
  end
end
