# Divergences from sdk-ruby

`sdk-ruby` is the reference for API coverage and request shapes. Where it is
demonstrably wrong, this SDK is correct instead. Every such case is listed here,
with the reason and whether it should be reported upstream.

Reference version: **sdk-ruby 3.4.0**.

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

## 6. Auto-pagination is a `Stream`, and it raises

**Ruby:** `pagination/iterator.rb` — an `Enumerable` class, exposed as
`search_auto_paging_iter` on `payment`, `customer` and `preapproval` only. It
breaks out of the loop on an empty page and silently ignores a failed request,
so a network error mid-walk looks like the end of the results.
**Elixir:** `Mercadopago.Pagination.stream/3`, plus `search_stream/3` on **every**
resource with a `search/3`, not three of them.

Two deliberate behaviour differences:

- A failed page **raises** — `Mercadopago.Error` for a status of 400 or above,
  the transport exception for a connection failure. A `Stream` has nowhere to
  put an error tuple, and truncating on failure would report a partial result as
  a complete one. Ruby's silence here is a bug we chose not to copy.
- A short page ends the walk, whatever `paging.total` claims. This also stops a
  server that ignores `offset` from looping forever.

**Report upstream: the silent-failure part, yes.**

## 7. One `Error` struct with `:kind`, not twelve exception classes

**Ruby:** `errors/exceptions.rb` defines `MercadoPagoError` plus eleven
subclasses, one per status, selected by a `build_error` factory.
**Elixir:** the single `Mercadopago.Error` gains a `:kind` atom carrying the same
classification, so `%Mercadopago.Error{kind: :rate_limit}` is matchable without
twelve modules in the docs. `:request_id` and `:retry_after` are fields on it
rather than an attribute of one subclass.

Rescuing by class is how Ruby dispatches; pattern-matching a field is how Elixir
does. The mapping itself is identical to Ruby's `STATUS_MAP`.

**Report upstream: no** (language-idiom difference).

## 8. `Subscription` delegates instead of duplicating

**Ruby:** `resources/subscription.rb` re-implements the four `/preapproval`
endpoints that `resources/preapproval.rb` already has, byte for byte.
**Elixir:** `Mercadopago.Subscription` exists for name parity, but every function
`defdelegate`s to `Mercadopago.Preapproval`.

Same requests either way; only one copy to keep correct.

**Report upstream: no** (housekeeping).

---

## Bugs the Ruby SDK had and this SDK never did

Recorded so a future sync does not "fix" something that was already right here.

- **`order.search` sent `params:` where `_get` expects `filters:`**
  (`resources/order.rb:161`, fixed in Ruby 3.4.0). `Mercadopago.Order.search/3`
  always passed its filters positionally to `HTTP.get/4`.
- **`disbursement_refund.create_all` omitted `data:`**
  (`resources/disbursement_refund.rb:26`, fixed in Ruby 3.4.0).
  `Mercadopago.DisbursementRefund.create_all/3` always passed `nil` explicitly.
- **`constant_time_equals` raised on a multibyte v1 hash**
  (fixed in Ruby 3.3.0). `Mercadopago.Webhook.Validator` guards on `byte_size/1`
  and then calls `:crypto.hash_equals/2`, which is byte-oriented.

And one the two SDKs shared, now fixed in both: the webhook `tolerance_seconds`
unit mismatch (Ruby 3.3.0, this SDK 0.3.0).

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
  Stores/POS and the Point → Orders/terminals migration are absent from both
  SDKs. Adding them is new scope, not a correction.
  (`GET /v1/payments/{id}/refunds/{refund_id}` was on this list; Ruby 3.3.0
  added it and so does this SDK, as `Mercadopago.Refund.get/4`.)

- **`Order::Request` typed builders.** Ruby 3.4.0 added 388 lines of
  `Data.define` classes mirroring the Orders create body
  (`resources/order/request.rb`), as an optional alternative to a plain Hash.
  Not ported: in Elixir a map already *is* the request, the structs would give
  no runtime checking that the API does not already give, and they would be a
  second API to keep in step with every field MercadoPago adds. A `@spec` on
  `Mercadopago.Order.create/3` documents the shape at no maintenance cost.

- **`MPResponse`.** Ruby 3.3.0 wrapped the response hash in a `Hash` subclass
  with `success?`, `raise_for_status!` and friends, for backward compatibility
  with code reading `result[:status]`. `Mercadopago.HTTP.unwrap/1` already covers
  this, and `{:ok, %{status: _, response: _}}` needs no wrapper to be matched.
