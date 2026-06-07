defmodule ApiManagementConsoleV2.RoutePolicies do
  @moduledoc """
  GenServer-backed store for route enable/disable policies.

  On start, loads persisted state from a DETS file. All toggles are
  written through to DETS immediately so state survives restarts.

  ## API

      iex> RoutePolicies.enabled?("/api/users")
      true

      iex> RoutePolicies.set_enabled("/api/users", false)
      :ok

      iex> RoutePolicies.all()
      %{"/api/users" => false, ...}

  ## Configuration

      config :api_management_console,
        dets_file: "tmp/api_policies.dets"
  """

  use GenServer

  @default_dets_file "tmp/api_policies.dets"

  # --- Public API ---

  @doc "Returns the enabled state for a single path."
  def enabled?(full_path) do
    GenServer.call(__MODULE__, {:enabled?, full_path})
  end

  @doc "Sets a single path as enabled or disabled."
  def set_enabled(full_path, enabled) when is_boolean(enabled) do
    GenServer.call(__MODULE__, {:set_enabled, full_path, enabled})
  end

  @doc "Returns the full policy map."
  def all do
    GenServer.call(__MODULE__, :all)
  end

  # --- GenServer ---

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    file = Application.get_env(:api_management_console, :dets_file, @default_dets_file)
    File.mkdir_p!(Path.dirname(file))
    {:ok, dets} = :dets.open_file(String.to_charlist(file), type: :set)
    state = %{dets: dets}
    {:ok, state}
  end

  @impl true
  def handle_call({:enabled?, full_path}, _from, state) do
    case :dets.lookup(state.dets, full_path) do
      [{_key, enabled}] -> {:reply, enabled, state}
      [] -> {:reply, true, state}
    end
  end

  @impl true
  def handle_call({:set_enabled, full_path, enabled}, _from, state) do
    :dets.insert(state.dets, {full_path, enabled})
    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:all, _from, state) do
    policies =
      state.dets
      |> :dets.match({:"$1", :"$2"})
      |> Map.new(fn [key, val] -> {key, val} end)

    {:reply, policies, state}
  end
end
