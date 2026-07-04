defmodule ApiManagementConsoleV2.BrandingTest do
  use ExUnit.Case, async: true

  alias ApiManagementConsoleV2.Branding

  describe "app_name/0" do
    test "returns default name for free tier" do
      assert Branding.app_name() == "API Management Console"
    end
  end

  describe "hide_powered_by?/0" do
    test "returns false for free tier" do
      assert Branding.hide_powered_by?() == false
    end
  end
end
