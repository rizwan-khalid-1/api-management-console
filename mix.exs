defmodule ApiManagementConsoleV2.MixProject do
  use Mix.Project

  def project do
    [
      app: :api_management_console,
      version: "0.1.0",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "A simple API route discovery tool for Phoenix apps",
      package: package()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {ApiManagementConsoleV2.Application, []}
    ]
  end

  defp deps do
    [
      {:phoenix, "~> 1.6 or ~> 1.7", optional: true},
      {:phoenix_live_view, "~> 0.20 or ~> 1.0", optional: true},
      {:cubdb, "~> 2.0"},
      {:bcrypt_elixir, "~> 3.0"},
      {:joken, "~> 2.6"}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/rizwankhalid/api_management_console"},
      files: ~w(lib mix.exs README.md LICENSE priv)
    ]
  end
end
