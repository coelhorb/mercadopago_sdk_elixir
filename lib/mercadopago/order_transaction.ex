defmodule Mercadopago.OrderTransaction do
  @moduledoc "Transaction management within an order."

  alias Mercadopago.{Client, HTTP}

  @doc "Creates a transaction within the given order."
  @spec create(Client.t(), HTTP.id(), map(), keyword()) :: HTTP.response()
  def create(%Client{} = client, order_id, order_transaction_data, opts \\ []) do
    HTTP.post(
      client,
      "/v1/orders/#{HTTP.encode_path_param(order_id)}/transactions",
      order_transaction_data,
      opts
    )
  end

  @doc "Updates a transaction within the given order."
  @spec update(Client.t(), HTTP.id(), HTTP.id(), map(), keyword()) :: HTTP.response()
  def update(%Client{} = client, order_id, transaction_id, order_transaction_data, opts \\ []) do
    HTTP.put(
      client,
      "/v1/orders/#{HTTP.encode_path_param(order_id)}/transactions/#{HTTP.encode_path_param(transaction_id)}",
      order_transaction_data,
      opts
    )
  end

  @doc "Deletes a transaction from the given order."
  @spec delete(Client.t(), HTTP.id(), HTTP.id(), keyword()) :: HTTP.response()
  def delete(%Client{} = client, order_id, transaction_id, opts \\ []) do
    HTTP.delete(
      client,
      "/v1/orders/#{HTTP.encode_path_param(order_id)}/transactions/#{HTTP.encode_path_param(transaction_id)}",
      opts
    )
  end
end
