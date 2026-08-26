# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.2]

### Changed

- **`req` floor lowered from `~> 0.7.4` to `~> 0.7.0`**, widening the range to
  the whole 0.7 line. Both forms already cap at `< 0.8.0` and pick up future
  0.7 patches; 0.7.4 was simply tighter than anything this SDK needs, and a
  library's bounds are a constraint imposed on every consumer's tree.

  The floor was set at 0.7.4 out of caution over `form_multipart`, which Req
  0.7.2 listed as "bring back `form_multipart: [{string_name, value}]`". That
  regression was in *string* part names; this SDK uses atoms, and the full suite
  passes against 0.7.0. Measured, not assumed.

  Note for anyone tempted to write `~> 0.7`: the two-part form means
  `>= 0.7.0 and < 1.0.0`, which would let Req 0.8 in. 0.8 drops Jason in favour
  of `JSON.encode!/2`, replaces the `retry` step with `Req.Retry`, and requires
  Elixir 1.18 — three minors above this SDK's floor.

## [0.3.1]

Dependency migration. No change to this SDK's own API — `Mercadopago.new/2`
still takes `finch: MyPool` as a bare name.

### Changed

- **`req` moved from the `0.6` line to `~> 0.7.4`.** The old bound meant
  `< 0.7.0`, so any application already on Req 0.7 could not resolve this SDK at
  all. Verified by running the full `mix ci` against 0.7.4: everything the bound
  was guarding survives untouched — `%Req.TransportError{}`,
  `Req.Response.get_header/2`, `Req.Test.transport_error/2`, and the `:plug`,
  `:params`, `:receive_timeout`, `:retry`, `:json` and `:form_multipart` options.

  **This is the breaking part for consumers**: an application pinned to Req 0.6
  can no longer use this version. Hex resolves that by falling back to 0.3.0
  rather than failing, so the practical effect is being held at the older
  release until Req is upgraded.

  The bound stays inside a single Req minor deliberately. Req 0.8 is not a bump
  away: it drops Jason in favour of `JSON.encode!/2`, replaces the `retry` step
  with `Req.Retry`, and requires Elixir 1.18 — three minors above this SDK's
  floor.

- `jason` raised to `~> 1.4`. Nothing in `lib/` calls it; Req encodes `:json`
  bodies and the tests decode with it. It cannot be scoped to `only: :test`,
  because Req depends on it unconditionally and Mix rejects an `:only` narrower
  than a transitive dependency's.

- `telemetry` deliberately **left at `~> 1.0`**. Only `:telemetry.span/3` and
  `:telemetry.execute/3` are used, both present since 1.0, and telemetry is
  shared with Phoenix, Ecto, Finch and Plug — a higher floor would buy nothing
  and could conflict in a consumer's tree.

### Fixed

- **The `:finch` option warned on every request under Req 0.7.** Req deprecated
  `finch: name` in favour of `finch: [name: name]`; the SDK passed the bare
  name, so any consumer using a dedicated Finch pool would have seen
  `setting :finch to a Finch pool name is deprecated` logged on every single
  call. The SDK's own `finch:` option is unchanged — the new shape is applied
  internally.

  This slipped through because no test exercised the `:finch` path: `:plug` and
  `:finch` are mutually exclusive adapters and all 125 existing tests use
  `:plug`. `test/mercadopago/finch_test.exs` now covers it, with a positive
  control asserting the warning is still detectable.

## [0.3.0]

Synced with the official Ruby SDK 3.4.0 (this SDK was at 3.2.1). See
[DIVERGENCES.md](DIVERGENCES.md) for every intentional departure from it.

No public function was removed or changed arity.

### Fixed

- **Webhook replay tolerance rejected every notification.**
  `Mercadopago.Webhook.Validator` compared the `ts` from the `x-signature`
  header, which MercadoPago sends in **seconds**, against a clock in
  **milliseconds**. The computed drift was therefore around 55 years, so
  **passing `tolerance_seconds:` rejected every webhook** with
  `:timestamp_out_of_tolerance` — the option meant to harden replay protection
  was the one thing that broke validation. Callers who left it unset were
  unaffected, which is why this went unnoticed. The reference Ruby SDK carried
  the same defect until 3.3.0. The test fixture used a millisecond `ts` and a
  clock derived from it, so it agreed with the bug; it now uses a realistic
  ten-digit `ts` and a real millisecond clock.

  **Every version published before this one is affected** — 0.1.0, 0.2.0 and
  0.2.1. The defect dates from the first commit. Two things to check before
  deploying the upgrade, both covered in
  [Upgrading from 0.2.x](README.md#upgrading-from-02x):

  1. Your webhook endpoint has been rejecting everything, so MercadoPago has
     been retrying. Those retries will start succeeding — **the handler must be
     idempotent**.
  2. If you worked around the bug by passing `:now` in seconds, that inverts:
     it used to widen the window 1000×, and now rejects everything. Drop the
     option or return `:os.system_time(:millisecond)`. The SDK warns when it is
     handed a clock in the wrong unit.

### Added

- `Mercadopago.Pagination.stream/3` and a `search_stream/3` on every resource
  with a `search/3` — `AdvancedPayment`, `Chargeback`, `Customer`, `Invoice`,
  `MerchantOrder`, `Order`, `Payment`, `Preapproval`, `PreapprovalPlan`,
  `Preference` and `Subscription`. Lazily walks the `limit`/`offset` pages and
  yields the records. Reads the `results`, `data` (Orders v2) and `elements`
  shapes, and accepts `paging.total` as an integer or a string. A failure
  mid-walk raises rather than truncating the stream silently.
- `:kind` on `Mercadopago.Error` — the class of failure as an atom
  (`:not_found`, `:rate_limit`, `:server`, …), from the same status mapping the
  Ruby SDK gives its twelve exception subclasses. One struct with a matchable
  field, rather than twelve modules.
- `:request_id` and `:retry_after` on `Mercadopago.Error`, lifted from the
  `x-request-id` and `Retry-After` response headers.
- `Mercadopago.Card.update/5`, `Mercadopago.Payment.capture/4`,
  `Mercadopago.Preference.search/3` and `Mercadopago.Refund.get/4`.
- `Mercadopago.Subscription`, mirroring the Ruby SDK's `sdk.subscription`. The
  same `/preapproval` endpoints `Mercadopago.Preapproval` already exposed; every
  function delegates to it.
- `:retry_on`, on the client and per call, to choose which HTTP statuses make a
  GET worth retrying (default `[429, 500, 502, 503, 504]`). Retryable transport
  failures are retried regardless.
- A warning when `Mercadopago.Webhook.Validator` is given a `:now` function
  returning what looks like seconds rather than milliseconds — the shape of the
  pre-0.3.0 workaround for the bug above, which stops working once the unit is
  correct.
- `[:mercadopago, :request, :retry]` telemetry event, fired just before each
  backoff sleep with `%{delay: milliseconds}` and the failed attempt's metadata.
  This is the SDK's equivalent of the Ruby SDK's `on_retry` callback.
- Examples for Automatic Payments through Orders
  (`examples/order/create_automatic_payment.exs`, the two-step CIT → MIT flow)
  and for CREDENTIAL_ON_FILE payments (`examples/payment/credential_on_file.exs`).
  Note the field is `previous_transaction_reference`; the Ruby SDK renamed it
  from `prev_transaction_ref` in 3.4.0.

### Changed

- The response map carries two more keys: `:request_id` and `:retry_after`, each
  `nil` when the server sent no such header. So a completed request is now
  `{:ok, %{status: _, response: _, request_id: _, retry_after: _}}`.
  Pattern matches on maps are partial, so `%{status: status, response: body}`
  keeps working — **the one thing that breaks is comparing the whole map for
  equality**, e.g. `result == {:ok, %{status: 200, response: body}}`. Match
  instead of comparing.

## [0.2.1]

Audited against MercadoPago's official MCP server
(`https://mcp.mercadopago.com/mcp`), walking the SDK's routes against the live
API documentation. Every finding was re-verified against the code before being
acted on; those that could not be confirmed were not acted on. See
[DIVERGENCES.md](DIVERGENCES.md) for every intentional departure from the
reference Ruby SDK.

No public function was removed or changed arity in this release.

### Fixed

- **Webhook signatures for Orders notifications.** `Mercadopago.Webhook.Validator`
  now lowercases `data.id` before building the HMAC manifest, as MercadoPago
  specifies: `id:[data.id_lowercase];request-id:[x-request-id];ts:[ts];`.
  Numeric payment ids have no case and were unaffected, which is why this went
  unnoticed — but the Orders API sends ULID-style ids such as
  `ORD01JQ4S4KY8HWQ6NA5PXB65B3D3`, and **every one of those notifications was
  being rejected as an invalid signature**. Callers pass `data.id` through
  untouched; the lowercasing is internal to the manifest. Anyone who worked
  around this by lowercasing the id themselves is unaffected.
  The reference Ruby SDK 3.2.1 has the same defect.
- **The `mix ci` alias could never fail on formatting.** It ran `format` before
  `format --check-formatted`, so the first task rewrote the files and the check
  always passed. It also mutated the working tree. Only the check remains.
- `Mercadopago.Order.create_online/3` no longer mixes atom and string keys when
  injecting defaults into a string-keyed payload.

### Added

- `Mercadopago.Order.create_online/3`, replacing the misnamed
  `create_checkout_pro/3` (see Deprecated).
- `Mercadopago.HTTP.patch/4`, unblocking endpoints that take a partial update.
- Multipart request bodies via `{:multipart, parts}` on `post/4`, `put/4` and
  `patch/4`, for uploads such as chargeback documentation. Part content may be a
  stream, so large files need not be read into memory.
- `Mercadopago.OAuth.generate_code_verifier/0` and
  `Mercadopago.OAuth.code_challenge/1` (PKCE, RFC 7636 S256), plus
  `:code_challenge` / `:code_challenge_method` options on
  `get_authorization_url/4`.
- Tokenless clients: `Mercadopago.new(nil)` omits the `Authorization` header
  instead of sending an empty `Bearer `. Previously the only way to bootstrap
  the OAuth authorization-code flow was `Mercadopago.new("")`.
- `Mercadopago.OAuth.create/3` and `refresh/3` default their own `grant_type`;
  an explicitly supplied one is never overwritten.
- `Mercadopago.Error` and the opt-in `Mercadopago.HTTP.unwrap/1`, for callers
  who prefer `{:ok, body}` / `{:error, exception}` over inspecting status codes.
  The default contract is unchanged: resource functions still return
  `{:ok, %{status: _, response: _}}` for every completed request.

### Deprecated

- `Mercadopago.Order.create_checkout_pro/3` — use `create_online/3`. The name is
  a misnomer inherited from the Ruby SDK: `POST /v1/orders` with `type: "online"`
  is the Checkout API via Orders, not Checkout Pro. Checkout Pro is the hosted
  flow built on `POST /checkout/preferences`, available as
  `Mercadopago.Preference`. The old name still works and delegates to the new one.

### Security

- Updated all dependencies to close five transport-layer CVEs.
- Bounded `req` to the `0.6` line: it is pre-1.0 and breaks API across minors,
  and the SDK matches on `%Req.TransportError{}` and calls
  `Req.Response.get_header/2` and `Req.Test.transport_error/2`.

### Changed

- Hardened the HTTP transport and restructured the integration suite into one
  module per resource, so `async: true` actually parallelises the network
  round-trips.

## [0.2.0]

- Synced with the official Ruby SDK 3.2.0.

## [0.1.0]

- Initial release.

[0.3.2]: https://github.com/coelhorb/mercadopago_sdk_elixir/tree/v0.3.2
[0.3.1]: https://github.com/coelhorb/mercadopago_sdk_elixir/tree/v0.3.1
[0.3.0]: https://github.com/coelhorb/mercadopago_sdk_elixir/tree/v0.3.0
[0.2.1]: https://github.com/coelhorb/mercadopago_sdk_elixir/tree/v0.2.1
[0.2.0]: https://github.com/coelhorb/mercadopago_sdk_elixir/tree/v0.2.0
[0.1.0]: https://github.com/coelhorb/mercadopago_sdk_elixir/tree/v0.1.0
