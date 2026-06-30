# Mercadopago Elixir SDK

[![Hex.pm](https://img.shields.io/hexpm/v/mercadopago_sdk_elixir.svg)](https://hex.pm/packages/mercadopago_sdk_elixir)
[![Hex Docs](https://img.shields.io/badge/hex-docs-blue.svg)](https://hexdocs.pm/mercadopago_sdk_elixir)
[![License](https://img.shields.io/hexpm/l/mercadopago_sdk_elixir.svg)](https://github.com/coelhorb/mercadopago_sdk_elixir/blob/main/LICENSE)

Elixir client for the [MercadoPago REST API](https://www.mercadopago.com.br/developers/pt/docs), ported from the official Ruby SDK.

## Installation

Add to `mix.exs`:

```elixir
def deps do
  [
    {:mercadopago_sdk_elixir, "~> 0.1.0"}
  ]
end
```

## Usage

```elixir
client = Mercadopago.new("YOUR_ACCESS_TOKEN")

# Create a payment
{:ok, %{status: 201, response: payment}} =
  Mercadopago.Payment.create(client, %{
    transaction_amount: 100.0,
    description: "Product",
    payment_method_id: "pix",
    payer: %{email: "buyer@example.com"}
  })

# Fetch a payment
{:ok, %{status: 200, response: payment}} =
  Mercadopago.Payment.get(client, payment["id"])
```

Per-call token override:

```elixir
Mercadopago.Payment.get(client, id, access_token: "OTHER_TOKEN")
```

## Testing

### Unit tests (no network, no token)

Use `Req.Test` stubs to intercept HTTP calls. The SDK exposes a `:plug` option
on the client that routes requests through the stub instead of the network.

A helper is provided in `test/support/stub_client.ex` (compiled only in the
`:test` env):

```elixir
# In your test file
import Mercadopago.Test.StubClient, only: [new: 1]

test "creates a payment" do
  Req.Test.stub(:payment_stub, fn conn ->
    conn
    |> Plug.Conn.put_status(201)
    |> Req.Test.json(%{"id" => "pay_123", "status" => "approved"})
  end)

  client = new(:payment_stub)

  assert {:ok, %{status: 201, response: %{"id" => "pay_123"}}} =
           Mercadopago.Payment.create(client, %{transaction_amount: 100})
end
```

`new/1` builds a client with `access_token: "test_token"` and
`plug: {Req.Test, stub_name}`. The stub receives a `%Plug.Conn{}` and must
return a response — use `Req.Test.json/2` for JSON bodies.

Run unit tests:

```bash
mix test
```

### Integration tests (real MercadoPago sandbox)

Tag integration tests with `@moduletag :integration`. They are excluded from
the default `mix test` run and require a sandbox `ACCESS_TOKEN`.

```elixir
defmodule Mercadopago.PaymentIntegrationTest do
  @moduletag :integration
  use ExUnit.Case

  setup do
    token = System.fetch_env!("ACCESS_TOKEN")
    {:ok, client: Mercadopago.new(token)}
  end

  test "search payments", %{client: client} do
    assert {:ok, %{status: 200, response: %{"results" => _}}} =
             Mercadopago.Payment.search(client)
  end
end
```

Run only integration tests:

```bash
ACCESS_TOKEN=APP_USR_xxx mix test --include integration
```

Run all tests (unit + integration):

```bash
ACCESS_TOKEN=APP_USR_xxx mix test --include integration --include test
```

## Webhook validation

```elixir
Mercadopago.Webhook.Validator.validate(
  x_signature,    # "ts=...;v1=..." header from MercadoPago
  x_request_id,   # x-request-id header
  data_id,        # params["data"]["id"] from the webhook body
  secret          # your webhook secret from the MercadoPago dashboard
)
# => :ok | raises Mercadopago.Webhook.InvalidSignatureError
```

Timestamp drift tolerance (default: no check):

```elixir
Mercadopago.Webhook.Validator.validate(x_sig, x_req, data_id, secret,
  max_age_seconds: 300
)
```
