defmodule Mercadopago.Integration.MerchantOrderTest do
  use ExUnit.Case, async: true

  alias Mercadopago.Test.IntegrationClient

  @moduletag :integration

  setup_all do
    {:ok, client: IntegrationClient.new()}
  end

  test "search/3 returns the elements envelope", %{client: client} do
    assert {:ok, %{status: 200, response: %{"elements" => elements}}} =
             Mercadopago.MerchantOrder.search(client, %{limit: 5})

    assert is_list(elements)
  end
end
