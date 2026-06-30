defmodule MercadopagoTest do
  use ExUnit.Case, async: true

  describe "new/2" do
    test "creates a client with access_token" do
      client = Mercadopago.new("my_token")
      assert client.access_token == "my_token"
      assert client.timeout == 60_000
      assert client.max_retries == 3
    end

    test "accepts custom options" do
      client =
        Mercadopago.new("my_token", timeout: 10_000, max_retries: 1, corporation_id: "corp")

      assert client.timeout == 10_000
      assert client.max_retries == 1
      assert client.corporation_id == "corp"
    end

    test "raises when access_token is not a string" do
      # credo:disable-for-next-line Credo.Check.Refactor.Apply
      assert_raise FunctionClauseError, fn -> apply(Mercadopago, :new, [123]) end
    end
  end
end
