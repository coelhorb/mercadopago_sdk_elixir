defmodule Mercadopago.MixProject do
  use Mix.Project

  @source_url "https://github.com/coelhorb/mercadopago_sdk_elixir"

  def project do
    [
      app: :mercadopago_sdk_elixir,
      version: "0.2.1",
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
      name: "mercadopago_sdk_elixir",
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "MercadoPago Developers" => "https://www.mercadopago.com.br/developers"
      },
      files: ~w(lib examples mix.exs README.md CHANGELOG.md DIVERGENCES.md LICENSE)
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "CHANGELOG.md", "DIVERGENCES.md"],
      source_url: @source_url,
      groups_for_modules: [
        Core: [
          Mercadopago,
          Mercadopago.Client,
          Mercadopago.HTTP,
          Mercadopago.Error,
          Mercadopago.Config
        ],
        Checkout: [Mercadopago.Preference, Mercadopago.Order, Mercadopago.OrderTransaction],
        Payments: [
          Mercadopago.Payment,
          Mercadopago.PaymentMethods,
          Mercadopago.Refund,
          Mercadopago.Chargeback,
          Mercadopago.CardToken,
          Mercadopago.MerchantOrder
        ],
        Customers: [Mercadopago.Customer, Mercadopago.Card, Mercadopago.IdentificationType],
        Subscriptions: [
          Mercadopago.Preapproval,
          Mercadopago.PreapprovalPlan,
          Mercadopago.Invoice
        ],
        Marketplace: [
          Mercadopago.OAuth,
          Mercadopago.AdvancedPayment,
          Mercadopago.DisbursementRefund
        ],
        "In-person": [Mercadopago.Point],
        Webhooks: [Mercadopago.Webhook.Validator],
        Account: [Mercadopago.User]
      ]
    ]
  end

  def application do
    [extra_applications: [:logger, :crypto]]
  end

  def cli do
    [preferred_envs: [ci: :test, "test.integration": :test]]
  end

  defp deps do
    [
      # Req is pre-1.0 and breaks API across minors, so the range is bounded to
      # the 0.6 line: the SDK matches on %Req.TransportError{} and calls
      # Req.Response.get_header/2 and Req.Test.transport_error/2.
      {:req, "~> 0.6.0"},
      {:jason, "~> 1.2"},
      {:telemetry, "~> 1.0"},
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
        "test --exclude integration",
        "credo --strict",
        "dialyzer",
        "cmd env MIX_ENV=dev mix docs --warnings-as-errors",
        "ex_dna --max-clones 0",
        "reach.check --arch --smells"
      ],
      "test.integration": ["cmd bash scripts/test_integration.sh"]
    ]
  end
end
