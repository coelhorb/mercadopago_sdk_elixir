client = Mercadopago.new(System.fetch_env!("MERCADOPAGO_ACCESS_TOKEN"))

order_data = %{
  external_reference: "ORDER-0001",
  total_amount: "500.00",
  payer: %{
    email: System.fetch_env!("MERCADOPAGO_PAYER_EMAIL"),
    first_name: "John",
    last_name: "Smith",
    identification: %{
      type: "CPF",
      number: "12345678909"
    },
    date_created: "2024-01-01T00:00:00Z",
    authentication_type: "Gmail",
    is_prime_user: false,
    is_first_purchase_online: false,
    last_purchase: "2024-01-01T00:00:00Z",
    registration_date: "2023-01-01T00:00:00Z"
  },
  shipment: %{
    mode: "custom",
    local_pickup: false,
    express_shipment: false,
    cost: "15.00",
    free_shipping: false,
    address: %{
      zip_code: "01310-100",
      street_name: "Av. Paulista",
      street_number: "1000",
      neighborhood: "Bela Vista",
      city: "Sao Paulo",
      state_name: "Sao Paulo",
      city_name: "Sao Paulo",
      floor: "2",
      apartment: "A"
    }
  },
  items: [
    %{
      external_code: "ITEM-001",
      title: "Flight SAO-RIO",
      description: "Economy class",
      quantity: 1,
      unit_price: "450.00",
      type: "travel",
      warranty: false,
      event_date: "2027-01-15T00:00:00.000-03:00",
      category_descriptor: %{
        passenger: %{
          first_name: "John",
          last_name: "Smith",
          identification: %{type: "CPF", number: "12345678909"}
        },
        route: %{
          departure: "SAO",
          destination: "RIO",
          departure_date_time: "2027-01-15T08:00:00.000-03:00",
          arrival_date_time: "2027-01-15T09:30:00.000-03:00",
          company: "LATAM"
        }
      }
    }
  ]
}

# Checkout API via Orders — not Checkout Pro. For the hosted Checkout Pro flow,
# create a preference instead (see examples/preference/).
{:ok, %{status: status, response: order}} =
  Mercadopago.Order.create_online(
    client,
    order_data,
    custom_headers: %{"X-Idempotency-Key" => System.fetch_env!("MERCADOPAGO_IDEMPOTENCY_KEY")}
  )

IO.inspect(%{status: status, order: order})
