defmodule Mercadopago.Chargeback do
  @moduledoc """
  Payment dispute (chargeback) retrieval and search.

  Read-only. Uploading supporting documentation is not exposed as a resource
  function, but the transport supports it — see the multipart body form in
  `Mercadopago.HTTP`.
  """

  alias Mercadopago.{Client, HTTP, Pagination}

  @doc "Fetches a chargeback by id."
  @spec get(Client.t(), HTTP.id(), keyword()) :: HTTP.response()
  def get(%Client{} = client, chargeback_id, opts \\ []) do
    HTTP.get(client, "/v1/chargebacks/#{HTTP.encode_path_param(chargeback_id)}", nil, opts)
  end

  @doc "Searches chargebacks matching `filters` (query-string parameters)."
  @spec search(Client.t(), map() | nil, keyword()) :: HTTP.response()
  def search(%Client{} = client, filters \\ nil, opts \\ []) do
    HTTP.get(client, "/v1/chargebacks/search", filters, opts)
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
