defmodule ApiManagementConsoleV2.Features do
  @moduledoc """
  Feature flag system based on license tier.

  Each feature is registered with a minimum required tier.
  Add new features here as they're built — no other code changes needed.

  ## Usage

      if Features.enabled?(:audit_log) do
        # render audit log section
      end

  ## Adding a new feature

  Just add it to `@features` with the required tier:

      @features %{
        ...
        scheduled_toggles: :paid
      }
  """

  alias ApiManagementConsoleV2.License

  @features %{
    # Free tier features (implemented)
    audit_log: :free,         # capped at 30-day history
    bulk_operations: :free,
    reset_all: :free,
    hide_routes: :free,
    rbac: :free,              # max 5 users (1 admin + 4 viewers)

    # Paid tier features
    company_branding: :paid,

    # Paid tier features (not yet implemented — uncomment when built)
    # unlimited_routes: :paid,  # free capped at 50 routes
    # scheduled_toggles: :paid,
    # postgresql_storage: :paid,
    # sso_integration: :paid,
    # slack_notifications: :paid,
  }

  @free_max_routes 50
  @free_max_users 5
  @free_audit_days 30

  @doc """
  Check if a feature is enabled for the current license tier.

  Returns `true` if the feature's minimum tier is satisfied.

  ## Examples

      iex> Features.enabled?(:route_discovery)
      true

      iex> Features.enabled?(:nonexistent)
      false
  """
  def enabled?(feature) when is_atom(feature) do
    case Map.fetch(@features, feature) do
      {:ok, required_tier} ->
        tier_satisfies?(License.get_tier(), required_tier)

      :error ->
        false
    end
  end

  @doc "Returns the current tier for display purposes."
  def current_tier, do: License.get_tier()

  @doc "Max number of routes allowed. Returns :unlimited for paid."
  def max_routes do
    if License.get_tier() == :paid, do: :unlimited, else: @free_max_routes
  end

  @doc "Max number of users allowed."
  def max_admins do
    if License.get_tier() == :paid, do: :unlimited, else: @free_max_users
  end

  @doc "Audit log retention in days."
  def audit_retention_days do
    if License.get_tier() == :paid, do: :unlimited, else: @free_audit_days
  end

  @doc "Returns true if the license is in a trial period."
  def trial?, do: License.in_trial?()

  @doc "Returns the license expiry date if set."
  def expires_at, do: License.expires_at()

  # --- Private ---

  defp tier_satisfies?(:paid, :free), do: true
  defp tier_satisfies?(:paid, :paid), do: true
  defp tier_satisfies?(:free, :free), do: true
  defp tier_satisfies?(:free, :paid), do: false
end
