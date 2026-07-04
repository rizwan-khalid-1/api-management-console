defmodule ApiManagementConsoleV2.LicenseTest do
  use ExUnit.Case, async: true

  alias ApiManagementConsoleV2.License

  describe "get_tier/0" do
    test "defaults to free without license key" do
      # No API_CONSOLE_LICENSE_KEY set in test env
      assert License.get_tier() == :free
    end
  end

  describe "expired?/0" do
    test "returns false without license key" do
      assert License.expired?() == false
    end
  end

  describe "in_trial?/0" do
    test "returns false without license key" do
      assert License.in_trial?() == false
    end
  end

  describe "expires_at/0" do
    test "returns nil without license key" do
      assert License.expires_at() == nil
    end
  end
end
