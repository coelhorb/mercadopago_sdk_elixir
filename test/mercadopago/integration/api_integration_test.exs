defmodule Mercadopago.ApiIntegrationTest do
  use ExUnit.Case
  @moduletag :integration

  setup_all do
    token = System.fetch_env!("ACCESS_TOKEN")
    {:ok, client: Mercadopago.new(token)}
  end

  describe "User" do
    test "get/1 returns authenticated user info", %{client: client} do
      result = Mercadopago.User.get(client)
      assert {:ok, %{status: 200, response: %{"id" => id}}} = result
      assert is_integer(id)
    end
  end

  describe "IdentificationType" do
    test "get/1 returns list of document types", %{client: client} do
      result = Mercadopago.IdentificationType.get(client)
      assert {:ok, %{status: 200, response: types}} = result
      assert [%{"id" => _, "name" => _} | _] = types
    end
  end

  describe "PaymentMethods" do
    test "get/1 returns available payment methods", %{client: client} do
      result = Mercadopago.PaymentMethods.get(client)
      assert {:ok, %{status: 200, response: methods}} = result
      assert [_ | _] = methods
    end
  end

  describe "Payment" do
    test "search/2 returns results and paging", %{client: client} do
      result = Mercadopago.Payment.search(client, %{limit: 5})
      assert {:ok, %{status: 200, response: %{"results" => results, "paging" => paging}}} = result
      assert is_list(results)
      assert %{"total" => _, "limit" => _, "offset" => _} = paging
    end
  end

  describe "Preference" do
    test "create/2 and get/2 round-trip", %{client: client} do
      payload = %{
        items: [
          %{
            title: "SDK Elixir Test Item",
            quantity: 1,
            unit_price: 10.0,
            currency_id: "BRL"
          }
        ],
        payer: %{email: "test_sdk@test.com"}
      }

      assert {:ok, %{status: 201, response: %{"id" => pref_id}}} =
               Mercadopago.Preference.create(client, payload)

      assert {:ok, %{status: 200, response: %{"id" => ^pref_id}}} =
               Mercadopago.Preference.get(client, pref_id)
    end
  end

  describe "MerchantOrder" do
    test "search/2 returns results", %{client: client} do
      result = Mercadopago.MerchantOrder.search(client, %{limit: 5})
      assert {:ok, %{status: 200, response: %{"elements" => _}}} = result
    end
  end
end
