defmodule Mercadopago.Integration.PaymentTest do
  use ExUnit.Case, async: true

  alias Mercadopago.Test.IntegrationClient

  @moduletag :integration

  setup_all do
    {:ok, client: IntegrationClient.new()}
  end

  test "search/3 returns results and paging", %{client: client} do
    assert {:ok,
            %{
              status: 200,
              response: %{
                "results" => results,
                "paging" => %{"total" => _, "limit" => _, "offset" => _}
              }
            }} = Mercadopago.Payment.search(client, %{limit: 5})

    # A fresh sandbox legitimately has no payments, so the list may be empty.
    assert is_list(results)
  end
end
