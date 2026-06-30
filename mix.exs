defmodule Mercadopago.MixProject do
  use Mix.Project

  @source_url "https://github.com/coelhorb/mercadopago_sdk_elixir"

  def project do
    [
      app: :mercadopago,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      description: "Elixir client for the MercadoPago REST API.",
      package: package(),
      docs: docs(),
      source_url: @source_url,
      aliases: aliases(),
      deps: deps(),
      dialyzer: [plt_add_apps: [:ex_unit], ignore_warnings: ".dialyzer_ignore.exs"]
    ]
  end

  defp package do
    [
      name: "mercadopago",
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "MercadoPago Developers" => "https://www.mercadopago.com.br/developers"
      },
      files: ~w(lib mix.exs README.md LICENSE)
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"],
      source_url: @source_url
    ]
  end

  def application do
    [extra_applications: [:logger, :crypto]]
  end

  def cli do
    [preferred_envs: [ci: :test]]
  end

  defp deps do
    [
      {:req, "~> 0.5"},
      {:jason, "~> 1.2"},
      {:plug, "~> 1.0", only: :test},
      {:vibe_kit, "~> 0.1", only: [:dev, :test], runtime: false},
      {:ex_slop, "~> 0.4", only: [:dev, :test], runtime: false},
      {:reach, "~> 2.0", only: [:dev, :test], runtime: false},
      {:ex_dna, "~> 1.0", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.0", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp aliases do
    [
      ci: [
        "compile --warnings-as-errors",
        "format --check-formatted",
        "test",
        "credo --strict",
        "dialyzer",
        "ex_dna --max-clones 0",
        "reach.check --arch --smells"
      ]
    ]
  end
end
