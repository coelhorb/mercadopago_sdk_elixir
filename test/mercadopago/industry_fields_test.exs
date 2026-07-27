defmodule Mercadopago.IndustryFieldsTest do
  use ExUnit.Case, async: true

  import Mercadopago.Test.StubClient, only: [new: 1]

  test "Payment.create/3 forwards payer and shipment industry fields" do
    Req.Test.stub(:payment_industry_fields, fn conn ->
      {body, conn} = decoded_body(conn)

      assert body["payer"]["authentication_type"] == "WEB"
      assert body["payer"]["is_prime_user"] == false
      assert body["payer"]["is_first_purchase_online"] == false
      assert body["shipments"]["express_shipment"] == false
      assert body["shipments"]["local_pickup"] == false
      assert body["shipments"]["receiver_address"]["floor"] == "3"
      assert body["shipments"]["receiver_address"]["apartment"] == "B"

      Req.Test.json(conn, %{"id" => "payment-1"})
    end)

    payment_data = %{
      payer: industry_payer(),
      shipments: %{
        express_shipment: false,
        local_pickup: false,
        receiver_address: industry_address()
      }
    }

    assert {:ok, %{status: 200}} =
             Mercadopago.Payment.create(new(:payment_industry_fields), payment_data)
  end

  test "Order.create_online/3 forwards item, payer, and shipment industry fields" do
    Req.Test.stub(:order_industry_fields, fn conn ->
      {body, conn} = decoded_body(conn)

      assert body["type"] == "online"
      assert body["processing_mode"] == "manual"
      assert body["payer"]["registration_date"] == "2023-01-01T00:00:00Z"
      assert body["shipment"]["express_shipment"] == false
      assert body["items"] |> hd() |> Map.fetch!("warranty") == false

      assert body["items"] |> hd() |> get_in(["category_descriptor", "route", "company"]) ==
               "LATAM"

      Req.Test.json(conn, %{"id" => "order-1"})
    end)

    order_data = %{
      total_amount: "450.00",
      payer: industry_payer(),
      shipment: %{
        express_shipment: false,
        local_pickup: false,
        address: industry_address()
      },
      items: [industry_item()]
    }

    assert {:ok, %{status: 200}} =
             Mercadopago.Order.create_online(new(:order_industry_fields), order_data)
  end

  test "Preference.create/3 forwards industry fields without filtering false values" do
    Req.Test.stub(:preference_industry_fields, fn conn ->
      {body, conn} = decoded_body(conn)

      assert body["payer"]["is_prime_user"] == false
      assert body["shipments"]["express_shipment"] == false
      assert body["items"] |> hd() |> Map.fetch!("warranty") == false

      assert body["items"] |> hd() |> get_in(["category_descriptor", "passenger", "first_name"]) ==
               "John"

      Req.Test.json(conn, %{"id" => "preference-1"})
    end)

    preference_data = %{
      payer: industry_payer(),
      shipments: %{
        express_shipment: false,
        local_pickup: false,
        receiver_address: industry_address()
      },
      items: [industry_item()]
    }

    assert {:ok, %{status: 200}} =
             Mercadopago.Preference.create(new(:preference_industry_fields), preference_data)
  end

  defp decoded_body(conn) do
    {:ok, body, conn} = Plug.Conn.read_body(conn)
    {Jason.decode!(body), conn}
  end

  defp industry_payer do
    %{
      authentication_type: "WEB",
      is_prime_user: false,
      is_first_purchase_online: false,
      last_purchase: "2024-01-01T00:00:00Z",
      registration_date: "2023-01-01T00:00:00Z",
      identification: %{type: "CPF", number: "19119119100"}
    }
  end

  defp industry_address do
    %{
      city_name: "Buzios",
      state_name: "Rio de Janeiro",
      floor: "3",
      apartment: "B"
    }
  end

  defp industry_item do
    %{
      title: "Flight SAO-RIO",
      quantity: 1,
      unit_price: 450.0,
      warranty: false,
      category_descriptor: %{
        passenger: %{first_name: "John", last_name: "Smith"},
        route: %{departure: "SAO", destination: "RIO", company: "LATAM"}
      }
    }
  end
end
