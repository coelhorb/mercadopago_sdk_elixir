defmodule Mercadopago.MerchantOrder do
  @moduledoc "Merchant orders that group multiple payments."

  alias Mercadopago.{Client, HTTP, Pagination}

  @doc "Searches merchant orders matching `filters` (query-string parameters)."
  @spec search(Client.t(), map() | nil, keyword()) :: HTTP.response()
  def search(%Client{} = client, filters \\ nil, opts \\ []) do
    HTTP.get(client, "/merchant_orders/search", filters, opts)
  end

  @doc """
  Streams every result of `search/3`, fetching each page as it is consumed.

  See `Mercadopago.Pagination.stream/3` for the options and for how failures are
  reported.
  """
  @spec search_stream(Client.t(), map() | nil, keyword()) :: Enumerable.t()
  def search_stream(%Client{} = client, filters \\ nil, opts \\ []) do
    Pagination.stream(&search(client, &1, opts), filters, opts)
  end

  @doc "Fetches a merchant order by id."
  @spec get(Client.t(), HTTP.id(), keyword()) :: HTTP.response()
  def get(%Client{} = client, merchant_order_id, opts \\ []) do
    HTTP.get(client, "/merchant_orders/#{HTTP.encode_path_param(merchant_order_id)}", nil, opts)
  end

  @doc "Creates a merchant order from `merchant_order_data`."
  @spec create(Client.t(), map(), keyword()) :: HTTP.response()
  def create(%Client{} = client, merchant_order_data, opts \\ []) do
    HTTP.post(client, "/merchant_orders", merchant_order_data, opts)
  end

  @doc "Updates a merchant order."
  @spec update(Client.t(), HTTP.id(), map(), keyword()) :: HTTP.response()
  def update(%Client{} = client, merchant_order_id, merchant_order_data, opts \\ []) do
    HTTP.put(
      client,
      "/merchant_orders/#{HTTP.encode_path_param(merchant_order_id)}",
      merchant_order_data,
      opts
    )
  end
end
