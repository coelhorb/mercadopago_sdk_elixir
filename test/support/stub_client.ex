defmodule Mercadopago.Test.StubClient do
  @moduledoc "Builds a test client that routes HTTP through a Req.Test stub."

  def new(stub_name, opts \\ []) do
    Mercadopago.new("test_token", Keyword.merge([plug: {Req.Test, stub_name}], opts))
  end
end
