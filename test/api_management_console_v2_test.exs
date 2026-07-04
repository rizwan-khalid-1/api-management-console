defmodule ApiManagementConsoleV2Test do
  use ExUnit.Case, async: true

  describe "list_routes/1" do
    test "returns empty list for non-existent module" do
      assert ApiManagementConsoleV2.list_routes(NonExistentModule) == []
    end
  end

  describe "list_routes_as_strings/1" do
    test "returns empty list for non-existent module" do
      assert ApiManagementConsoleV2.list_routes_as_strings(NonExistentModule) == []
    end
  end
end
