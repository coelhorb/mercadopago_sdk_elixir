defmodule Mercadopago.ResourcesTest do
  @moduledoc """
  Behaviour of the resource functions added in 0.3.0, beyond the path encoding
  already swept by `Mercadopago.PathParamTest`.
  """

  use ExUnit.Case, async: true

  import Mercadopago.Test.StubClient, only: [new: 1]

  # Echoes the method, path, query string and decoded body back to the test.
  defp echo(name) do
    test_pid = self()

    Req.Test.stub(name, fn conn ->
      {:ok, raw, conn} = Plug.Conn.read_body(conn)
      body = if raw == "", do: nil, else: Jason.decode!(raw)

      send(test_pid, {:request, conn.method, conn.request_path, conn.query_string, body})

      Req.Test.json(conn, %{"ok" => true})
    end)

    new(name)
  end

  describe "Payment.capture/4" do
    test "captures the full authorized amount when none is given" do
      client = echo(:capture_full)

      assert {:ok, %{status: 200}} = Mercadopago.Payment.capture(client, "pay_1")
      assert_received {:request, "PUT", "/v1/payments/pay_1", _query, %{"capture" => true} = body}
      refute Map.has_key?(body, "transaction_amount")
    end

    test "captures a partial amount when one is given" do
      client = echo(:capture_partial)

      assert {:ok, %{status: 200}} = Mercadopago.Payment.capture(client, "pay_1", 42.5)

      assert_received {:request, "PUT", "/v1/payments/pay_1", _query,
                       %{"capture" => true, "transaction_amount" => 42.5}}
    end
  end

  describe "Card.update/5" do
    test "PUTs the card data to the customer's card" do
      client = echo(:card_update)

      assert {:ok, %{status: 200}} =
               Mercadopago.Card.update(client, "cus_1", "card_1", %{expiration_year: 2030})

      assert_received {:request, "PUT", "/v1/customers/cus_1/cards/card_1", _query,
                       %{"expiration_year" => 2030}}
    end
  end

  describe "Refund.get/4" do
    test "GETs a single refund of a payment" do
      client = echo(:refund_get)

      assert {:ok, %{status: 200}} = Mercadopago.Refund.get(client, "pay_1", "ref_1")
      assert_received {:request, "GET", "/v1/payments/pay_1/refunds/ref_1", _query, _body}
    end
  end

  describe "Preference.search/3" do
    test "GETs the preference search endpoint with the filters as query params" do
      client = echo(:preference_search)

      assert {:ok, %{status: 200}} =
               Mercadopago.Preference.search(client, %{external_reference: "ref-9"})

      assert_received {:request, "GET", "/checkout/preferences/search", query, _body}
      assert URI.decode_query(query) == %{"external_reference" => "ref-9"}
    end
  end

  describe "Subscription" do
    test "create/3 POSTs to the preapproval collection" do
      client = echo(:subscription_create)

      assert {:ok, %{status: 200}} =
               Mercadopago.Subscription.create(client, %{preapproval_plan_id: "plan_1"})

      assert_received {:request, "POST", "/preapproval/", _query,
                       %{"preapproval_plan_id" => "plan_1"}}
    end

    test "search/3 GETs the preapproval search endpoint" do
      client = echo(:subscription_search)

      assert {:ok, %{status: 200}} =
               Mercadopago.Subscription.search(client, %{status: "authorized"})

      assert_received {:request, "GET", "/preapproval/search", query, _body}
      assert URI.decode_query(query) == %{"status" => "authorized"}
    end
  end
end
