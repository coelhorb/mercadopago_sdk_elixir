defmodule Mercadopago.DisbursementRefund do
  @moduledoc "Refunds on individual disbursements within an advanced payment (marketplace split)."

  alias Mercadopago.{Client, HTTP}

  @doc "Lists refunds for the given advanced payment."
  @spec list(Client.t(), String.t(), keyword()) :: HTTP.response()
  def list(%Client{} = client, advanced_payment_id, opts \\ []) do
    HTTP.get(client, "/v1/advanced_payments/#{advanced_payment_id}/refunds", nil, opts)
  end

  @doc "Refunds every disbursement of the given advanced payment."
  @spec create_all(Client.t(), String.t(), keyword()) :: HTTP.response()
  def create_all(%Client{} = client, advanced_payment_id, opts \\ []) do
    HTTP.post(client, "/v1/advanced_payments/#{advanced_payment_id}/refunds", nil, opts)
  end

  @doc "Refunds a single disbursement; pass `amount` for a partial refund."
  @spec create(Client.t(), String.t(), String.t(), number() | nil, keyword()) :: HTTP.response()
  def create(%Client{} = client, advanced_payment_id, disbursement_id, amount \\ nil, opts \\ []) do
    body = if amount, do: %{amount: amount}, else: nil

    HTTP.post(
      client,
      "/v1/advanced_payments/#{advanced_payment_id}/disbursements/#{disbursement_id}/refunds",
      body,
      opts
    )
  end
end
