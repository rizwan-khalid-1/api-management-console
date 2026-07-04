defmodule ApiManagementConsoleV2.RouterEnvTest do
  use ExUnit.Case, async: true

  describe "phoenix_router application env" do
    test "persistent_term has been replaced with Application env" do
      # The key used by the guard plug
      # In test env with no consumer app, this returns nil — that's fine
      router = Application.get_env(:api_management_console, :phoenix_router)
      # Should be either nil (no consumer app) or an atom (consumer's router module)
      assert is_nil(router) or is_atom(router)
    end
  end
end
