defmodule ApiManagementConsoleV2.MixProject do
  use Mix.Project

  def project do
    [
      app: :api_management_console_v2,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "A simple API route discovery tool for Phoenix apps",
      package: package()
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [
      {:phoenix, "~> 1.6 or ~> 1.7", optional: true}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/rizwankhalid/api_management_console"},
      files: ~w(lib mix.exs README.md LICENSE)
    ]
  end
end
