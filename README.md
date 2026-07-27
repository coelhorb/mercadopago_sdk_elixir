# Mercadopago Elixir SDK

[![Hex.pm](https://img.shields.io/hexpm/v/mercadopago_sdk_elixir.svg)](https://hex.pm/packages/mercadopago_sdk_elixir)
[![Hex Docs](https://img.shields.io/badge/hex-docs-blue.svg)](https://hexdocs.pm/mercadopago_sdk_elixir)
[![License](https://img.shields.io/hexpm/l/mercadopago_sdk_elixir.svg)](https://github.com/coelhorb/mercadopago_sdk_elixir/blob/main/LICENSE)

Elixir client for the [MercadoPago REST API](https://www.mercadopago.com.br/developers/pt/docs), ported from the official Ruby SDK (feature parity with `mercadopago-sdk` 3.2.1).

## Validated against MercadoPago's MCP server

Every public method in this SDK was cross-checked against MercadoPago's live API
documentation through their official MCP server:

```bash
claude mcp add --transport http mercadopago https://mcp.mercadopago.com/mcp
```

Of the 62 distinct verb/route pairs the SDK exposes, 41 were confirmed against
the current documentation, 8 target APIs MercadoPago now classifies as legacy,
and the remainder are either undocumented in the public reference or corroborated
only indirectly. One contradicted the docs outright and was fixed.

Every finding was then re-verified against the source before being acted on —
several did not survive that check, including a claim that Checkout Pro was
missing (it is implemented as `Mercadopago.Preference`). To be clear about what
this means: the MCP server is a documentation source, not a conformance suite. It
tells you what the API says it does, not that this client is certified.

## What changed in 0.2.1

| Change | Why it matters |
| --- | --- |
| Webhook `data.id` is lowercased before the HMAC | **Orders webhooks were being rejected outright.** Numeric payment ids were unaffected, so this was invisible unless you used the Orders API |
| `Order.create_online/3` replaces `create_checkout_pro/3` | The old name pointed at the wrong integration; it still works, deprecated |
| `HTTP.patch/4` and multipart bodies | Unblocks partial updates and document uploads |
| OAuth PKCE + tokenless clients | The authorization-code flow no longer needs a fake empty token |
| `HTTP.unwrap/1` and `Mercadopago.Error` | Opt-in `{:ok, body}` / `{:error, exception}` style |

No public function was removed or changed arity. Full detail in
[CHANGELOG.md](CHANGELOG.md); every intentional departure from the reference Ruby
SDK is recorded in [DIVERGENCES.md](DIVERGENCES.md).

## Installation

Add to `mix.exs`:

```elixir
def deps do
  [
    {:mercadopago_sdk_elixir, "~> 0.2.1"}
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

### Checkout Pro

Checkout Pro is the hosted flow: you create a payment preference and redirect the
buyer to the `init_point` MercadoPago returns.

```elixir
{:ok, %{status: 201, response: preference}} =
  Mercadopago.Preference.create(client, %{
    external_reference: "order-0001",
    items: [
      %{title: "Product", unit_price: 100.0, quantity: 1, currency_id: "BRL"}
    ],
    back_urls: %{
      success: "https://shop.example/success",
      failure: "https://shop.example/failure"
    }
  })

redirect_to = preference["init_point"]
```

### Online orders (Checkout API via Orders)

A different integration from Checkout Pro, despite the similar shape.
`Mercadopago.Order.create_online/3` wraps `Order.create/3` and applies the
two-step defaults `type: "online"` and `processing_mode: "manual"` when omitted,
raising `ArgumentError` if incompatible values are given:

```elixir
{:ok, %{status: 201, response: order}} =
  Mercadopago.Order.create_online(client, %{
    external_reference: "order-0001",
    total_amount: "100.00",
    items: [
      %{title: "Product", unit_price: "100.00", quantity: 1}
    ]
  })

# order["type"] == "online", order["processing_mode"] == "manual"

# Settle it afterwards:
{:ok, %{status: 200}} = Mercadopago.Order.process(client, order["id"])
```

> `Order.create_checkout_pro/3` is the deprecated former name of
> `create_online/3`. It still works, but it named the wrong integration — use
> `Mercadopago.Preference` for Checkout Pro.

### Industry-specific fields

Payment, Order, and Preference payloads are open maps, so industry-specific
fields are forwarded to MercadoPago without filtering. This includes payer
authentication details, enriched shipment addresses, item warranties, and
travel descriptors with passenger and route data.

Complete examples:

- [Payment with industry fields](examples/payment/create_with_industry_fields.exs)
- [Online Order with industry fields](examples/order/create_online.exs)
- [Preference with industry fields](examples/preference/create_with_industry_fields.exs)

### Per-call options

Every resource call accepts options that override the client configuration
for that single request:

```elixir
Mercadopago.Payment.get(client, id, access_token: "OTHER_TOKEN")

# Pin the idempotency key of one POST (case-insensitive override of the
# generated x-idempotency-key header):
Mercadopago.Order.create_online(client, order_data,
  custom_headers: %{"X-Idempotency-Key" => my_key}
)

Mercadopago.Payment.search(client, filters, timeout: 5_000, max_retries: 1)
```

Supported keys: `:access_token`, `:custom_headers`, `:timeout` (ms), and — for
GET only — `:max_retries`, `:retry_delay` and `:max_retry_delay`.

### Error handling

Every completed request returns `{:ok, %{status: _, response: _}}` — a `404`
included. `{:error, reason}` is reserved for transport failures. Pipe through
`Mercadopago.HTTP.unwrap/1` when you would rather branch on `{:ok, _}` /
`{:error, _}` than on the status code:

```elixir
case client |> Mercadopago.Payment.get(id) |> Mercadopago.HTTP.unwrap() do
  {:ok, payment} -> payment
  {:error, %Mercadopago.Error{status: 404}} -> nil
  {:error, %Mercadopago.Error{} = e} -> Logger.error(Exception.message(e))
end
```

`unwrap/1` is a pure function over an already-returned response, so it changes
nothing about how requests are made. `Mercadopago.Error` carries `:status`,
the untouched `:response` body, and MercadoPago's `:cause` list when present.

### Uploads and partial updates

`Mercadopago.HTTP.patch/4` covers endpoints that take a partial update. For
`multipart/form-data`, pass `{:multipart, parts}` as the body — part content may
be a stream, so large files are not read into memory:

```elixir
Mercadopago.HTTP.post(client, "/v1/chargebacks/#{id}/documentation",
  {:multipart, [
    {:kind, "invoice"},
    {:file, {File.stream!("proof.pdf", 2048),
             filename: "proof.pdf", content_type: "application/pdf"}}
  ]}
)
```

### OAuth (marketplaces)

The token endpoint needs no prior credentials, so bootstrap it with a tokenless
client. PKCE is optional on MercadoPago but costs nothing to include:

```elixir
verifier = Mercadopago.OAuth.generate_code_verifier()

url =
  Mercadopago.OAuth.get_authorization_url(app_id, redirect_uri, state,
    code_challenge: Mercadopago.OAuth.code_challenge(verifier)
  )

# ...redirect the seller to `url`, then on the callback:

{:ok, %{status: 200, response: %{"access_token" => token}}} =
  Mercadopago.OAuth.create(Mercadopago.new(nil), %{
    client_id: app_id,
    client_secret: app_secret,
    code: code,
    redirect_uri: redirect_uri,
    code_verifier: verifier
  })
```

Store `verifier` in the session alongside `state`; both must survive the
redirect. `grant_type` defaults to `authorization_code` for `create/3` and
`refresh_token` for `refresh/3`.

### Retry policy

A GET is retried when the response status is `429`, `500`, `502`, `503` or
`504`, or when the request fails with a retryable transport error (connection
closed under the pool, refused or unreachable host). A `:timeout` is **not**
retried — the receive timeout has already spent the latency budget. Mutating
verbs are never retried.

Backoff starts at `:retry_delay`, doubles per attempt, is capped by
`:max_retry_delay` and gets jitter added, so concurrent callers do not come
back in lockstep after an incident. A `Retry-After` header takes precedence but
is capped just the same, so a mistaken `Retry-After: 3600` cannot pin the
calling process for an hour.

```elixir
# Defaults: 3 attempts total, 1s base backoff, 8s ceiling
client = Mercadopago.new(token, max_retries: 3, retry_delay: 1_000, max_retry_delay: 8_000)
```

All attempts reuse the same `x-idempotency-key`, so a retried request is not
processed twice by MercadoPago.

The wait **blocks the calling process**. Worst-case latency for a GET is roughly
`max_retries * timeout` plus the accumulated backoff — with the defaults, up to
about three minutes. Lower `:timeout` for calls made inside a web request.

### Telemetry

Every attempt, retries included, is wrapped in a `:telemetry.span/3`:

| Event | Measurements | Metadata |
| --- | --- | --- |
| `[:mercadopago, :request, :start]` | `:system_time` | `:method`, `:path`, `:attempt` |
| `[:mercadopago, :request, :stop]` | `:duration` | above plus `:status` or `:error` |
| `[:mercadopago, :request, :exception]` | `:duration` | above plus `:kind`, `:reason`, `:stacktrace` |

`:attempt` is zero-based, so retries are distinguishable from first tries.
Neither the access token nor the request body is ever included in metadata.

```elixir
:telemetry.attach("mercadopago-logger", [:mercadopago, :request, :stop], fn _event, %{duration: duration}, metadata, _config ->
  Logger.info("mercadopago #{metadata.method} #{metadata.path} -> #{metadata[:status]} in #{System.convert_time_unit(duration, :native, :millisecond)}ms")
end, nil)
```

### Connection pooling

By default requests go through Req's shared Finch pool. For high-throughput
applications, start a dedicated [Finch](https://hex.pm/packages/finch) pool in
your supervision tree and point the client at it:

```elixir
# In your application supervisor
{Finch, name: MyApp.MercadopagoFinch, pools: %{default: [size: 25]}}

# When building the client
client = Mercadopago.new(token, finch: MyApp.MercadopagoFinch)
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
defmodule Mercadopago.Integration.PaymentTest do
  use ExUnit.Case, async: true

  @moduletag :integration

  setup_all do
    {:ok, client: Mercadopago.new(System.fetch_env!("ACCESS_TOKEN"))}
  end

  test "search payments", %{client: client} do
    assert {:ok, %{status: 200, response: %{"results" => _}}} =
             Mercadopago.Payment.search(client)
  end
end
```

**One module per resource.** ExUnit's `async: true` is module-granular: tests
inside a single module always run sequentially, so piling every resource into
one module serialises every network round-trip. Split by resource and the whole
suite costs about one round-trip instead of their sum — that is why
`test/mercadopago/integration/` has a file per resource.

Keep the SDK's worst case under ExUnit's 60s per-test timeout, otherwise a
flaky sandbox gets killed by ExUnit instead of surfacing the SDK's own error.
`Mercadopago.Test.IntegrationClient` does this by tightening the retry budget
to `timeout: 10_000, max_retries: 2, max_retry_delay: 2_000`.

Run only integration tests:

```bash
cp .env.integration.example .env.integration
chmod 600 .env.integration
# Add the application's test ACCESS_TOKEN to .env.integration, then run:
mix test.integration
```

Only the test Access Token is required. The Public Key, application number,
Client ID, and Client Secret are not used by this test suite. The local
`.env.integration` file is ignored by Git and the runner never prints its
contents. Do not use a production credential.

Run all tests (unit + integration) after creating `.env.integration`:

```bash
set -a
source .env.integration
set +a
mix test --include integration --include test
```

## Webhook validation

```elixir
case Mercadopago.Webhook.Validator.validate(
       x_signature,    # "ts=...,v1=..." header from MercadoPago
       x_request_id,   # x-request-id header
       data_id,        # params["data"]["id"] from the webhook body
       secret          # your webhook secret from the MercadoPago dashboard
     ) do
  {:ok, _ts} -> :ok
  {:error, %Mercadopago.Webhook.Validator.InvalidSignatureError{} = e} -> handle_error(e)
end
```

Timestamp drift tolerance (default: no check):

```elixir
Mercadopago.Webhook.Validator.validate(x_sig, x_req, data_id, secret,
  tolerance_seconds: 300
)
```

Raising variant (`validate!/5`) is also available — raises
`Mercadopago.Webhook.Validator.InvalidSignatureError` on failure instead of
returning `{:error, _}`.

Pass `data_id` exactly as received. MercadoPago builds the signature manifest
from the **lowercased** id, and the validator handles that internally — the
Orders API sends ids like `ORD01JQ4S4KY8HWQ6NA5PXB65B3D3` that only verify once
downcased. Use the original value when fetching the resource.

Legacy QR Code notifications are not signed and will always fail validation. QR
payments delivered through the Orders API *are* signed and should be validated
like any other event.
