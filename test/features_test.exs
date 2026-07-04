defmodule ApiManagementConsoleV2.FeaturesTest do
  use ExUnit.Case, async: true

  alias ApiManagementConsoleV2.Features

  describe "comparison/0" do
    test "returns feature list with free and paid info" do
      comparison = Features.comparison()
      assert is_list(comparison)
      assert length(comparison) > 0

      for item <- comparison do
        assert Map.has_key?(item, :name)
        assert Map.has_key?(item, :free)
        assert Map.has_key?(item, :paid)
      end
    end

    test "includes key features" do
      names = Features.comparison() |> Enum.map(& &1.name)
      assert "Managed Routes" in names
      assert "User Accounts" in names
      assert "Audit Log History" in names
      assert "Company Branding" in names
    end
  end

  describe "max_routes/0" do
    test "returns integer cap for free tier" do
      assert is_integer(Features.max_routes())
    end
  end

  describe "max_admins/0" do
    test "returns integer cap for free tier" do
      assert is_integer(Features.max_admins())
    end
  end

  describe "audit_retention_days/0" do
    test "returns integer for free tier" do
      assert is_integer(Features.audit_retention_days())
    end
  end

  describe "at_route_limit?/1" do
    test "returns true when exceeding cap" do
      cap = Features.max_routes()
      assert Features.at_route_limit?(cap + 1) == true
    end

    test "returns false when under cap" do
      assert Features.at_route_limit?(0) == false
    end
  end

  describe "capped_route_count/1" do
    test "returns min of total and cap" do
      cap = Features.max_routes()
      assert Features.capped_route_count(cap + 100) == cap
      assert Features.capped_route_count(10) == 10
    end
  end

  describe "routes_over_cap/1" do
    test "returns count beyond cap" do
      cap = Features.max_routes()
      assert Features.routes_over_cap(cap + 5) == 5
      assert Features.routes_over_cap(cap) == 0
      assert Features.routes_over_cap(0) == 0
    end
  end

  describe "enabled?/1" do
    test "returns true for free-tier features" do
      assert Features.enabled?(:audit_log) == true
      assert Features.enabled?(:bulk_operations) == true
      assert Features.enabled?(:rbac) == true
    end

    test "returns false for paid features in free tier" do
      assert Features.enabled?(:company_branding) == false
    end

    test "returns false for unknown features" do
      assert Features.enabled?(:nonexistent_feature) == false
    end
  end

  describe "current_tier/0" do
    test "returns a known tier" do
      assert Features.current_tier() in [:free, :paid]
    end
  end
end
