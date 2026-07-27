# Divergences from sdk-ruby

`sdk-ruby` is the reference for API coverage and request shapes. Where it is
demonstrably wrong, this SDK is correct instead. Every such case is listed here,
with the reason and whether it should be reported upstream.

Reference version: **sdk-ruby 3.2.1**.

---

## 1. Webhook manifest lowercases `data.id`

**Ruby:** `lib/mercadopago/webhook/validator.rb:158-164` interpolates `data_id`
verbatim.
**Elixir:** `lib/mercadopago/webhook/validator.ex` downcases it before the HMAC.

MercadoPago documents the manifest as
`id:[data.id_lowercase];request-id:[x-request-id];ts:[ts];` and gives the worked
example `ORD01JQ4S4KY8HWQ6NA5PXB65B3D3` → `ord01jq4s4ky8hwq6na5pxb65b3d3`.

Numeric payment ids have no case, so the two SDKs agree there. They diverge for
the ULID-style ids the Orders API sends, where Ruby computes the wrong HMAC and
rejects valid notifications.

Ruby's own docstring at `validator.rb:87` already claims "Lowercased before
HMAC" — the intent was there, the code never matched it.

**Report upstream: yes.** This is a live bug in the Ruby SDK.

## 2. `Order.create_online/3` replaces `create_checkout_pro/3`

**Ruby:** `lib/mercadopago/resources/order.rb:84`, named `create_checkout_pro`.
**Elixir:** `create_online/3`, with `create_checkout_pro/3` kept as a
`@deprecated` delegate so existing callers keep working.

`POST /v1/orders` with `type: "online"` is the **Checkout API (via Orders)**,
which MercadoPago documents under `docs/checkout-api-orders/`. Checkout Pro is
the hosted flow built on `POST /checkout/preferences` — already implemented here
as `Mercadopago.Preference`. The Ruby name sends users to the wrong integration.

Behaviour is unchanged; only the name and documentation differ.

**Report upstream: yes** (naming/doc issue, not a functional bug).

## 3. Transport supports PATCH and multipart

**Ruby:** `HttpClient` exposes GET/POST/PUT/DELETE only. `resources/point.rb:11-13`
documents a missing method *because of* that limitation.
**Elixir:** `Mercadopago.HTTP.patch/4`, plus `{:multipart, parts}` bodies on
`post/4`, `put/4` and `patch/4`.

Additive — no existing behaviour changes. Unblocks the Point operating-mode
endpoint and chargeback documentation upload, neither of which is exposed as a
resource function yet.

**Report upstream: no** (Ruby limitation, not an error).

## 4. OAuth gains PKCE and a tokenless bootstrap

**Ruby:** `resources/oauth.rb` builds a fixed five-parameter authorization URL;
`create` and `refresh` are identical and rely on the caller to set `grant_type`.
**Elixir:** `get_authorization_url/4` accepts `:code_challenge` /
`:code_challenge_method`; `generate_code_verifier/0` and `code_challenge/1`
implement RFC 7636 S256; `create/3` and `refresh/3` default their own
`grant_type` (an explicit one is never overwritten).

Also: `Mercadopago.new/2` now accepts `nil`, and the `Authorization` header is
omitted for a blank or nil token. Previously the only way to call `/oauth/token`
before holding a token was `Mercadopago.new("")`, which sent a literal `Bearer `.

PKCE is optional on MercadoPago today; it is offered, never forced.

**Report upstream: no** (enhancement).

## 5. `Mercadopago.HTTP.unwrap/1` and `Mercadopago.Error`

**Ruby:** every completed response is `{ status:, response: }`; the caller checks
the status.
**Elixir:** the same contract is preserved by default. `unwrap/1` is an opt-in
pure function mapping 4xx/5xx to `{:error, %Mercadopago.Error{}}` and a success
to `{:ok, body}`.

No resource function changed. Deliberately additive so existing integrations —
`loja_da_ana` among them — keep compiling.

**Report upstream: no** (language-idiom addition).

---

## Deliberately *not* diverged

- **`x-idempotency-key` on GET/DELETE/OAuth.** Ruby builds one header set for all
  verbs (`core/mp_base.rb:59`) and this SDK matches it. Sending the key on safe
  verbs is harmless — MercadoPago ignores it — and a divergence here would buy
  nothing.
- **`tolerance_seconds` still defaults to nil.** Replay tolerance depends on the
  integrator's clock skew, so silently enforcing a window would reject valid
  webhooks for anyone with drift. It stays a caller decision, documented in
  `Mercadopago.Webhook.Validator`.
- **Resource coverage.** Reports, Shipping, Claims, Customer Addresses,
  Stores/POS, the Point → Orders/terminals migration and
  `GET /v1/payments/{id}/refunds/{refund_id}` are absent from both SDKs. Adding
  them is new scope, not a correction.
