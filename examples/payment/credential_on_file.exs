# CREDENTIAL_ON_FILE (COF) payments — the replacement for the deprecated
# SUBSCRIPTIONS type, for recurring and unscheduled charges on a stored card.
#
# Three scenarios, all driven by `point_of_interaction.transaction_data`:
#
#   CIT      customer-initiated enrollment. The customer authorizes the first
#            charge and consents to storing the credential. `storage: "store"`.
#   MIT      merchant-initiated recurring charge, no customer present.
#            `storage: "stored"`, and `reference.id` points at the CIT payment.
#   UCOF-CIT unscheduled customer-initiated purchase on a stored credential —
#            the customer is present, but neither amount nor date was agreed.

client = Mercadopago.new(System.fetch_env!("MERCADOPAGO_ACCESS_TOKEN"))

payer = %{
  email: System.fetch_env!("MERCADOPAGO_PAYER_EMAIL"),
  identification: %{type: "CPF", number: "12345678909"}
}

card_token = System.fetch_env!("MERCADOPAGO_CARD_TOKEN")
payment_method_id = System.fetch_env!("MERCADOPAGO_PAYMENT_METHOD_ID")

base = %{
  token: card_token,
  installments: 1,
  payment_method_id: payment_method_id,
  payer: payer
}

create = fn payment_data, idempotency_key ->
  {:ok, %{status: status, response: payment}} =
    Mercadopago.Payment.create(client, payment_data,
      custom_headers: %{"X-Idempotency-Key" => idempotency_key}
    )

  IO.inspect(%{status: status, id: payment["id"], payment_status: payment["status"]})
  payment
end

# ── 1. CIT — enrollment ─────────────────────────────────────────────────────
cit =
  create.(
    Map.merge(base, %{
      transaction_amount: 100.00,
      description: "Monthly subscription — enrollment",
      point_of_interaction: %{
        linked_to: "subscription",
        transaction_data: %{
          type: "CREDENTIAL_ON_FILE",
          sub_type: "recurring",
          storage: "store",
          transaction_initiator: "customer",
          first_transaction: true
        }
      }
    }),
    "cof-enrollment-001"
  )

# ── 2. MIT — recurring charge anchored to the CIT payment ───────────────────
create.(
  Map.merge(base, %{
    transaction_amount: 100.00,
    description: "Monthly subscription — recurring charge",
    point_of_interaction: %{
      linked_to: "subscription",
      transaction_data: %{
        type: "CREDENTIAL_ON_FILE",
        sub_type: "recurring",
        storage: "stored",
        transaction_initiator: "merchant",
        first_transaction: false,
        reference: %{id: to_string(cit["id"])}
      }
    }
  }),
  "cof-recurring-002"
)

# ── 3. UCOF-CIT — unscheduled purchase on the stored credential ─────────────
create.(
  Map.merge(base, %{
    transaction_amount: 250.00,
    description: "One-off purchase with stored credentials",
    point_of_interaction: %{
      linked_to: "subscription",
      transaction_data: %{
        type: "CREDENTIAL_ON_FILE",
        sub_type: "unscheduled",
        storage: "stored",
        transaction_initiator: "customer",
        first_transaction: false
      }
    }
  }),
  "cof-unscheduled-003"
)
