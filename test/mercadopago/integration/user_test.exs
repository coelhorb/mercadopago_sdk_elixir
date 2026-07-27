defmodule Mercadopago.Integration.UserTest do
  use ExUnit.Case, async: true

  alias Mercadopago.Test.IntegrationClient

  @moduletag :integration

  setup_all do
    {:ok, client: IntegrationClient.new()}
  end

  test "get/2 returns the authenticated user", %{client: client} do
    assert {:ok, %{status: 200, response: %{"id" => id}}} = Mercadopago.User.get(client)

    # MercadoPago returns account ids as numbers, which is what HTTP.id() covers.
    assert is_integer(id)
  end
end
