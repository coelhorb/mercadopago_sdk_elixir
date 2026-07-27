defmodule Mercadopago.Integration.PreferenceTest do
  use ExUnit.Case, async: true

  alias Mercadopago.Test.IntegrationClient

  @moduletag :integration

  setup_all do
    {:ok, client: IntegrationClient.new()}
  end

  test "create/3 and get/3 round-trip", %{client: client} do
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
