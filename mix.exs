defmodule Mercadopago.MixProject do
  use Mix.Project

  @source_url "https://github.com/coelhorb/mercadopago_sdk_elixir"

  def project do
    [
      app: :mercadopago_sdk_elixir,
      version: "0.3.2",
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
          Mercadopago.Pagination,
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
          Mercadopago.Subscription,
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
      # Req is pre-1.0 and breaks API across minors, so the range is bounded to a
      # single line: the SDK matches on %Req.TransportError{}, calls
      # Req.Response.get_header/2 and Req.Test.transport_error/2, and passes
      # :plug, :finch, :receive_timeout, :params, :json and :form_multipart.
      # 0.8 is not a bump away — it drops jason for JSON, replaces the retry step
      # with Req.Retry, and requires Elixir 1.18, three minors above our floor.
      # The floor is 0.7.0 because the suite passes there: 0.7.2 restored
      # form_multipart for *string* part names, and this SDK uses atoms.
      {:req, "~> 0.7.0"},
      # Only :telemetry.span/3 and :telemetry.execute/3 are used, both present
      # since 1.0. Telemetry is shared with Phoenix, Ecto, Finch and Plug, so a
      # higher floor here would buy nothing and could conflict in a consumer's
      # tree.
      {:telemetry, "~> 1.0"},
      # lib/ never calls Jason — Req encodes :json bodies and the tests decode
      # with it. It cannot be scoped to :test: Req depends on it unconditionally,
      # and Mix rejects an :only narrower than a transitive dependency's.
      {:jason, "~> 1.4"},
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
