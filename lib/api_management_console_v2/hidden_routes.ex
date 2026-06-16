defmodule ApiManagementConsoleV2.HiddenRoutes do
  @moduledoc false

  alias ApiManagementConsoleV2.RoutePolicies.Store

  def hide(keys) when is_list(keys), do: Store.hide(keys)
  def show(keys) when is_list(keys), do: Store.show(keys)
  def all_keys, do: Store.hidden_keys()
  def count, do: Store.hidden_count()
end
