defmodule Mercadopago.MerchantOrder do
  @moduledoc "Merchant orders that group multiple payments."

  @behaviour Mercadopago.Resource

  alias Mercadopago.{Client, HTTP}

  @doc "Searches merchant orders matching `filters` (query-string parameters)."
  @spec search(Client.t(), map() | nil, keyword()) :: HTTP.response()
  def search(%Client{} = client, filters \\ nil, opts \\ []) do
    HTTP.get(client, "/merchant_orders/search", filters, opts)
  end

  @doc "Fetches a merchant order by id."
  @spec get(Client.t(), String.t(), keyword()) :: HTTP.response()
  def get(%Client{} = client, merchant_order_id, opts \\ []) do
    HTTP.get(client, "/merchant_orders/#{merchant_order_id}", nil, opts)
  end

  @doc "Creates a merchant order from `merchant_order_data`."
  @spec create(Client.t(), map(), keyword()) :: HTTP.response()
  def create(%Client{} = client, merchant_order_data, opts \\ []) do
    HTTP.post(client, "/merchant_orders", merchant_order_data, opts)
  end

  @doc "Updates a merchant order."
  @spec update(Client.t(), String.t(), map(), keyword()) :: HTTP.response()
  def update(%Client{} = client, merchant_order_id, merchant_order_data, opts \\ []) do
    HTTP.put(client, "/merchant_orders/#{merchant_order_id}", merchant_order_data, opts)
  end
end
