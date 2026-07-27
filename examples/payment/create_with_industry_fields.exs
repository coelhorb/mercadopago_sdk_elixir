client = Mercadopago.new(System.fetch_env!("MERCADOPAGO_ACCESS_TOKEN"))

payment_data = %{
  transaction_amount: 100.0,
  description: "Product with delivery",
  payment_method_id: "pix",
  payer: %{
    email: System.fetch_env!("MERCADOPAGO_PAYER_EMAIL"),
    first_name: "John",
    last_name: "Smith",
    phone: %{
      area_code: "011",
      number: "987654321"
    },
    authentication_type: "WEB",
    is_prime_user: false,
    is_first_purchase_online: false,
    last_purchase: "2024-01-01T00:00:00Z",
    identification: %{
      type: "CPF",
      number: "19119119100"
    }
  },
  shipments: %{
    express_shipment: false,
    local_pickup: false,
    receiver_address: %{
      street_name: "Av das Nacoes Unidas",
      street_number: 3003,
      zip_code: "06233200",
      city_name: "Buzios",
      state_name: "Rio de Janeiro",
      floor: "3",
      apartment: "B"
    }
  }
}

{:ok, %{status: status, response: payment}} =
  Mercadopago.Payment.create(
    client,
    payment_data,
    custom_headers: %{"X-Idempotency-Key" => System.fetch_env!("MERCADOPAGO_IDEMPOTENCY_KEY")}
  )

IO.inspect(%{status: status, payment: payment})
