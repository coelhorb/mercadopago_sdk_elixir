# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.1]

Audited against MercadoPago's official MCP server
(`https://mcp.mercadopago.com/mcp`), which cross-checks every public method
against the live API documentation. Findings were re-verified against the code
before being acted on. See [DIVERGENCES.md](DIVERGENCES.md) for every
intentional departure from the reference Ruby SDK.

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

[0.2.1]: https://github.com/coelhorb/mercadopago_sdk_elixir/tree/v0.2.1
[0.2.0]: https://github.com/coelhorb/mercadopago_sdk_elixir/tree/v0.2.0
[0.1.0]: https://github.com/coelhorb/mercadopago_sdk_elixir/tree/v0.1.0
