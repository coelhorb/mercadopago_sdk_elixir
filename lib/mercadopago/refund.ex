defmodule Mercadopago.Refund do
  @moduledoc "Full or partial payment refunds."

  alias Mercadopago.{Client, HTTP}

  @doc "Lists refunds for the given payment."
  @spec list(Client.t(), String.t(), keyword()) :: HTTP.response()
  def list(%Client{} = client, payment_id, opts \\ []) do
    HTTP.get(client, "/v1/payments/#{payment_id}/refunds", nil, opts)
  end

  @doc "Refunds the given payment; omit `refund_data` for a full refund."
  @spec create(Client.t(), String.t(), map() | nil, keyword()) :: HTTP.response()
  def create(%Client{} = client, payment_id, refund_data \\ nil, opts \\ []) do
    HTTP.post(client, "/v1/payments/#{payment_id}/refunds", refund_data, opts)
  end
end
