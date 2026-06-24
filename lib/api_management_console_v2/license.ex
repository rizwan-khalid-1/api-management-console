defmodule ApiManagementConsoleV2.License do
  @moduledoc """
  Offline license validation using signed JWT tokens.

  The consumer sets `API_CONSOLE_LICENSE_KEY` in their environment.
  The library validates the signature against an embedded public key
  and extracts claims (tier, expiry, trial info).

  ## License claims

      {
        "tier": "paid" | "free",
        "expires_at": "2026-12-31" (ISO8601, optional),
        "trial": true | false,
        "trial_start": "2026-01-01" (ISO8601),
        "trial_days": 30
      }

  ## Usage

      License.get_tier()     # => :paid | :free
      License.expired?()     # => true | false
      License.in_trial?()    # => true | false
  """

  @public_key_file Path.join(:code.priv_dir(:api_management_console), "keys/public_key.pem")

  @doc "Returns the current license tier: :paid or :free."
  def get_tier do
    case license_key() do
      nil -> :free
      key -> validate(key)
    end
  end

  @doc "Returns true if the license has expired."
  def expired? do
    case license_key() do
      nil -> false
      key ->
        case parse_claims(key) do
          {:ok, claims} -> is_expired?(claims)
          _ -> false
        end
    end
  end

  @doc "Returns true if currently in a trial period."
  def in_trial? do
    case license_key() do
      nil -> false
      key ->
        case parse_claims(key) do
          {:ok, claims} -> Map.get(claims, "trial", false)
          _ -> false
        end
    end
  end

  @doc "Returns the expiry date if set, nil otherwise."
  def expires_at do
    case license_key() do
      nil -> nil
      key ->
        case parse_claims(key) do
          {:ok, %{"expires_at" => expires}} -> expires
          _ -> nil
        end
    end
  end

  # --- Private ---

  defp license_key do
    System.get_env("API_CONSOLE_LICENSE_KEY") ||
      Application.get_env(:api_management_console, :license_key)
  end

  defp validate(key) do
    case parse_claims(key) do
      {:ok, claims} ->
        if is_expired?(claims) do
          :free
        else
          String.to_existing_atom(claims["tier"] || "free")
        end

      _ ->
        :free
    end
  end

  defp parse_claims(key) do
    public_key = read_public_key()
    signer = Joken.Signer.create("RS256", %{"pem" => public_key})

    case Joken.verify(key, signer) do
      {:ok, claims} -> {:ok, claims}
      {:error, reason} ->
        IO.inspect(reason, label: "[License] verify error")
        :error
    end
  rescue
    e ->
      IO.inspect(e, label: "[License] exception")
      :error
  end

  defp is_expired?(claims) do
    # Check explicit expiry
    expires = Map.get(claims, "expires_at")

    if expires do
      case Date.from_iso8601(expires) do
        {:ok, date} -> Date.compare(date, Date.utc_today()) == :lt
        _ -> true
      end
    else
      # Check trial expiry
      if Map.get(claims, "trial", false) do
        trial_start = Map.get(claims, "trial_start")
        trial_days = Map.get(claims, "trial_days", 30)

        if trial_start do
          case Date.from_iso8601(trial_start) do
            {:ok, start} ->
              Date.diff(Date.utc_today(), start) > trial_days

            _ ->
              true
          end
        else
          false
        end
      else
        false
      end
    end
  end

  defp read_public_key do
    File.read!(@public_key_file)
  rescue
    _ -> raise "Public key not found at #{@public_key_file}. Ensure priv/keys/public_key.pem is included in your release."
  end
end
