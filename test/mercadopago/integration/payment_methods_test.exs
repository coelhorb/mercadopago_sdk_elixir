defmodule Mercadopago.Integration.PaymentMethodsTest do
  use ExUnit.Case, async: true

  alias Mercadopago.Test.IntegrationClient

  @moduletag :integration

  setup_all do
    {:ok, client: IntegrationClient.new()}
  end

  test "get/2 lists the available payment methods", %{client: client} do
    assert {:ok, %{status: 200, response: [%{"id" => _} | _]}} =
             Mercadopago.PaymentMethods.get(client)
  end
end
