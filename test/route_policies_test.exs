defmodule ApiManagementConsoleV2.RoutePoliciesTest do
  use ExUnit.Case, async: false

  alias ApiManagementConsoleV2.RoutePolicies
  alias ApiManagementConsoleV2.RoutePolicies.Store

  setup do
    Store.reset_all()
    :ok
  end

  describe "set_route_enabled/2 and enabled?/1" do
    test "toggles a route and returns old state" do
      key = "get|/test/route"
      old_state = RoutePolicies.set_route_enabled(key, false)
      assert is_boolean(old_state)
      assert RoutePolicies.enabled?(key) == false

      old_state2 = RoutePolicies.set_route_enabled(key, true)
      assert old_state2 == false
      assert RoutePolicies.enabled?(key) == true
    end

    test "returns true for unknown routes" do
      assert RoutePolicies.enabled?("get|/nonexistent") == true
    end
  end

  describe "console_route?/1" do
    test "identifies console paths" do
      assert RoutePolicies.console_route?("/admin/api-console") == true
      assert RoutePolicies.console_route?("/admin/api-console/logout") == true
      assert RoutePolicies.console_route?("/admin/api-console/audit.csv") == true
    end

    test "returns false for non-console paths" do
      assert RoutePolicies.console_route?("/api/users") == false
      assert RoutePolicies.console_route?("/") == false
    end
  end

  describe "reset_all/0" do
    test "clears all policies but preserves selection" do
      RoutePolicies.set_route_enabled("get|/test/a", false)
      RoutePolicies.set_route_enabled("get|/test/b", false)
      Store.set_selection(["get|/test/a", "get|/test/b"])
      assert RoutePolicies.enabled?("get|/test/a") == false
      assert RoutePolicies.selection_count() == 2

      RoutePolicies.reset_all()
      assert RoutePolicies.enabled?("get|/test/a") == true
      assert RoutePolicies.enabled?("get|/test/b") == true
      # Selection must survive reset
      assert RoutePolicies.selection_count() == 2
      assert RoutePolicies.in_selection?("get|/test/a")
    end
  end

  describe "toggle vs concurrent access" do
    test "toggle returns old state correctly" do
      key = "get|/test/concurrent"
      old = RoutePolicies.set_route_enabled(key, false)
      assert is_boolean(old)

      old2 = RoutePolicies.set_route_enabled(key, true)
      assert old2 == false
      assert RoutePolicies.enabled?(key) == true
    end
  end

  describe "Store.toggle_group/2" do
    test "toggles multiple routes atomically" do
      keys = ["get|/test/g1", "get|/test/g2", "get|/test/g3"]

      # Set all to false
      results = Store.toggle_group(keys, false)
      assert is_list(results)
      assert length(results) == 3

      for {_, old} <- results, do: assert is_boolean(old)

      for key <- keys, do: assert RoutePolicies.enabled?(key) == false
    end
  end

  describe "Store.bulk_put/1" do
    test "updates multiple routes atomically" do
      updates = [{"get|/test/b1", false}, {"get|/test/b2", true}]
      results = Store.bulk_put(updates)
      assert is_list(results)
      assert length(results) == 2

      assert RoutePolicies.enabled?("get|/test/b1") == false
      assert RoutePolicies.enabled?("get|/test/b2") == true
    end
  end

  describe "Store.hide/1 and Store.show/1" do
    test "hides and shows routes" do
      keys = ["get|/test/hidden"]

      # Hide
      Store.hide(keys)
      hidden = Store.hidden_keys()
      assert "get|/test/hidden" in hidden
      assert Store.hidden_count() == 1

      # Show
      Store.show(keys)
      hidden2 = Store.hidden_keys()
      refute "get|/test/hidden" in hidden2
      assert Store.hidden_count() == 0
    end
  end

  describe "Store.get_selection/0 and set_selection/1" do
    test "returns empty set by default" do
      assert MapSet.size(Store.get_selection()) == 0
    end

    test "persists and retrieves selection" do
      keys = ["get|/test/s1", "get|/test/s2", "get|/test/s3"]
      Store.set_selection(keys)
      selection = Store.get_selection()

      assert MapSet.size(selection) == 3
      assert MapSet.member?(selection, "get|/test/s1")
      assert MapSet.member?(selection, "get|/test/s2")
      assert MapSet.member?(selection, "get|/test/s3")
    end
  end

  describe "Store.add_to_selection/1 and remove_from_selection/1" do
    test "adds and removes keys atomically" do
      Store.set_selection(["get|/test/s1"])
      Store.add_to_selection(["get|/test/s2", "get|/test/s3"])
      assert MapSet.size(Store.get_selection()) == 3

      Store.remove_from_selection(["get|/test/s1"])
      selection = Store.get_selection()
      assert MapSet.size(selection) == 2
      refute MapSet.member?(selection, "get|/test/s1")
      assert MapSet.member?(selection, "get|/test/s2")
    end
  end

  describe "RoutePolicies.selection_count/0 and in_selection?/1" do
    test "returns 0 when no selection" do
      Store.set_selection([])
      assert RoutePolicies.selection_count() == 0
    end

    test "returns correct count after setting selection" do
      Store.set_selection([])
      Store.set_selection(["get|/test/c1", "get|/test/c2"])
      assert RoutePolicies.selection_count() == 2
    end

    test "checks membership correctly" do
      Store.set_selection([])
      Store.set_selection(["get|/test/c1"])
      assert RoutePolicies.in_selection?("get|/test/c1") == true
      assert RoutePolicies.in_selection?("get|/test/c2") == false
    end
  end
end
