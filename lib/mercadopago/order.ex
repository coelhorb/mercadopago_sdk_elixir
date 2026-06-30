defmodule Mercadopago.Order do
  @moduledoc "Order lifecycle: create, process, capture, refund, cancel, and search."

  alias Mercadopago.{Client, HTTP}

  @doc "Creates an order from `order_data`."
  @spec create(Client.t(), map(), keyword()) :: HTTP.response()
  def create(%Client{} = client, order_data, opts \\ []) do
    HTTP.post(client, "/v1/orders", order_data, opts)
  end

  @doc "Fetches an order by id."
  @spec get(Client.t(), String.t(), keyword()) :: HTTP.response()
  def get(%Client{} = client, order_id, opts \\ []) do
    HTTP.get(client, "/v1/orders/#{order_id}", nil, opts)
  end

  @doc "Processes a previously created order."
  @spec process(Client.t(), String.t(), keyword()) :: HTTP.response()
  def process(%Client{} = client, order_id, opts \\ []) do
    HTTP.post(client, "/v1/orders/#{order_id}/process", nil, opts)
  end

  @doc "Refunds an order, fully or partially via `refund_data`."
  @spec refund(Client.t(), String.t(), map() | nil, keyword()) :: HTTP.response()
  def refund(%Client{} = client, order_id, refund_data \\ nil, opts \\ []) do
    HTTP.post(client, "/v1/orders/#{order_id}/refund", refund_data, opts)
  end

  @doc "Cancels an order."
  @spec cancel(Client.t(), String.t(), keyword()) :: HTTP.response()
  def cancel(%Client{} = client, order_id, opts \\ []) do
    HTTP.post(client, "/v1/orders/#{order_id}/cancel", nil, opts)
  end

  @doc "Captures an authorized order."
  @spec capture(Client.t(), String.t(), keyword()) :: HTTP.response()
  def capture(%Client{} = client, order_id, opts \\ []) do
    HTTP.post(client, "/v1/orders/#{order_id}/capture", nil, opts)
  end

  @doc "Searches orders matching `filters` (query-string parameters)."
  @spec search(Client.t(), map() | nil, keyword()) :: HTTP.response()
  def search(%Client{} = client, filters \\ nil, opts \\ []) do
    HTTP.get(client, "/v1/orders", filters, opts)
  end
end
