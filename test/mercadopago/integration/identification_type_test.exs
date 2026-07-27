defmodule Mercadopago.Integration.IdentificationTypeTest do
  use ExUnit.Case, async: true

  alias Mercadopago.Test.IntegrationClient

  @moduletag :integration

  setup_all do
    {:ok, client: IntegrationClient.new()}
  end

  test "get/2 lists the supported document types", %{client: client} do
    assert {:ok, %{status: 200, response: [%{"id" => _, "name" => _} | _]}} =
             Mercadopago.IdentificationType.get(client)
  end
end
