defmodule Mercadopago.PaymentMethods do
  @moduledoc "Lists available payment methods for the account."

  alias Mercadopago.{Client, HTTP}

  @doc "Lists the payment methods available to the authenticated account."
  @spec get(Client.t(), keyword()) :: HTTP.response()
  def get(%Client{} = client, opts \\ []) do
    HTTP.get(client, "/v1/payment_methods", nil, opts)
  end
end
