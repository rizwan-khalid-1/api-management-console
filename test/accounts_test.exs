defmodule ApiManagementConsoleV2.AccountsTest do
  use ExUnit.Case, async: false

  alias ApiManagementConsoleV2.Accounts

  setup do
    # Ensure default admin exists for tests
    Accounts.ensure_admin_exists()
    :ok
  end

  describe "ensure_admin_exists/0" do
    test "creates a default admin if none exists" do
      admins = Accounts.list() |> Enum.filter(&(&1.role == :admin))
      assert length(admins) >= 1
    end
  end

  describe "authenticate/2" do
    test "returns error for non-existent user" do
      assert {:error, :invalid_credentials} = Accounts.authenticate("nonexistent", "password")
    end

    test "returns error for wrong password" do
      assert {:error, :invalid_credentials} = Accounts.authenticate("admin", "wrongpassword")
    end

    test "returns ok with correct credentials" do
      assert {:ok, :admin} = Accounts.authenticate("admin", "admin123")
    end
  end

  describe "create/3" do
    test "creates a new user" do
      username = "test_user_#{System.unique_integer()}"
      assert :ok = Accounts.create(username, "password123", :viewer)

      account = Enum.find(Accounts.list(), &(&1.username == username))
      assert account != nil
      assert account.role == :viewer
    end

    test "returns error for duplicate username" do
      assert {:error, :already_exists} = Accounts.create("admin", "password", :viewer)
    end
  end

  describe "can_create?/0" do
    test "returns a boolean" do
      assert is_boolean(Accounts.can_create?())
    end

    test "respects user limit when at capacity" do
      # Fill up to 5 users, then check can_create? returns false
      existing = Accounts.list()
      remaining = max(5 - length(existing), 0)

      if remaining > 0 do
        for i <- 1..remaining do
          Accounts.create("fill_#{i}_#{System.unique_integer()}", "pass", :viewer)
        end
      end

      # Now at capacity — should be blocked
      expect = length(Accounts.list()) >= 5
      assert Accounts.can_create?() == !expect
    end
  end

  describe "set_role/2" do
    test "changes user role" do
      username = "role_test_#{System.unique_integer()}"
      Accounts.create(username, "pass", :viewer)
      assert :ok = Accounts.set_role(username, :admin)

      account = Enum.find(Accounts.list(), &(&1.username == username))
      assert account.role == :admin
    end
  end
end
