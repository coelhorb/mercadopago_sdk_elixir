# Automatic Payments through the Orders API — the two-step recurring flow.
#
#   Step 1 (CIT, customer-initiated): a CVV-validated charge that registers the
#          card credential. `first_payment: true`, no previous reference.
#   Step 2 (MIT, merchant-initiated): every later charge. No card token — the
#          payment profile carries the credential — and
#          `previous_transaction_reference` links it to the original consent.
#
# Prerequisites, both created beforehand:
#   * a customer            → POST /v1/customers
#   * a payment profile     → POST /v1/customers/{customer_id}/payment-profiles

client = Mercadopago.new(System.fetch_env!("MERCADOPAGO_ACCESS_TOKEN"))

customer_id = System.fetch_env!("MERCADOPAGO_CUSTOMER_ID")
payment_profile_id = System.fetch_env!("MERCADOPAGO_PAYMENT_PROFILE_ID")
payer_email = System.fetch_env!("MERCADOPAGO_PAYER_EMAIL")
card_token = System.fetch_env!("MERCADOPAGO_CARD_TOKEN")

# ── Step 1: first payment (CIT) ─────────────────────────────────────────────
first_payment = %{
  type: "online",
  processing_mode: "automatic",
  total_amount: "100.00",
  external_reference: "subscription-001-payment-1",
  payer: %{email: payer_email, customer_id: customer_id},
  transactions: %{
    payments: [
      %{
        amount: "100.00",
        payment_method: %{
          id: "master",
          type: "credit_card",
          token: card_token,
          installments: 1
        },
        automatic_payments: %{payment_profile_id: payment_profile_id},
        stored_credential: %{
          payment_initiator: "customer",
          reason: "recurring",
          first_payment: true
        }
      }
    ]
  }
}

{:ok, %{status: 201, response: order}} =
  Mercadopago.Order.create(client, first_payment,
    custom_headers: %{"X-Idempotency-Key" => "subscription-001-payment-1"}
  )

# The id of the payment inside the order anchors every later charge.
previous_transaction_reference =
  order |> Map.fetch!("transactions") |> Map.fetch!("payments") |> hd() |> Map.fetch!("id")

IO.inspect(%{order_id: order["id"], first_payment_id: previous_transaction_reference})

# ── Step 2: recurring charge (MIT) ──────────────────────────────────────────
# `processing_mode: "automatic_async"` lets MercadoPago schedule and retry the
# charge; `subscription_data` describes the billing cycle it belongs to.
sequence_number = 2

recurring_charge = %{
  type: "online",
  processing_mode: "automatic_async",
  total_amount: "100.00",
  external_reference: "subscription-001-payment-#{sequence_number}",
  payer: %{email: payer_email, customer_id: customer_id},
  transactions: %{
    payments: [
      %{
        amount: "100.00",
        automatic_payments: %{
          payment_profile_id: payment_profile_id,
          retries: 3,
          schedule_date: "2026-09-01T00:00:00.000-04:00",
          due_date: "2026-09-05T00:00:00.000-04:00"
        },
        stored_credential: %{
          payment_initiator: "merchant",
          reason: "recurring",
          first_payment: false,
          previous_transaction_reference: previous_transaction_reference
        },
        subscription_data: %{
          invoice_id: "INV-00#{sequence_number}",
          billing_date: "2026-08-01",
          subscription_sequence: %{number: sequence_number, total: 12},
          invoice_period: %{type: "monthly", period: 1}
        }
      }
    ]
  }
}

{:ok, %{status: status, response: recurring}} =
  Mercadopago.Order.create(client, recurring_charge,
    custom_headers: %{
      "X-Idempotency-Key" => "subscription-001-payment-#{sequence_number}"
    }
  )

IO.inspect(%{
  status: status,
  order_id: recurring["id"],
  order_status: recurring["status"],
  status_detail: recurring["status_detail"]
})
