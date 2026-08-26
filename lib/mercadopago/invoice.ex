defmodule Mercadopago.Invoice do
  @moduledoc "Subscription billing invoice retrieval."

  alias Mercadopago.{Client, HTTP, Pagination}

  @doc "Fetches an authorized-payment invoice by id."
  @spec get(Client.t(), HTTP.id(), keyword()) :: HTTP.response()
  def get(%Client{} = client, invoice_id, opts \\ []) do
    HTTP.get(client, "/authorized_payments/#{HTTP.encode_path_param(invoice_id)}", nil, opts)
  end

  @doc "Searches invoices matching `filters` (query-string parameters)."
  @spec search(Client.t(), map() | nil, keyword()) :: HTTP.response()
  def search(%Client{} = client, filters \\ nil, opts \\ []) do
    HTTP.get(client, "/authorized_payments/search", filters, opts)
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
end
