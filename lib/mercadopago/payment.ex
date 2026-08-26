defmodule Mercadopago.Payment do
  @moduledoc "Payment operations via the Checkout API."

  alias Mercadopago.{Client, HTTP, Pagination}

  @doc "Searches payments matching `filters` (query-string parameters)."
  @spec search(Client.t(), map() | nil, keyword()) :: HTTP.response()
  def search(%Client{} = client, filters \\ nil, opts \\ []) do
    HTTP.get(client, "/v1/payments/search", filters, opts)
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

  @doc "Fetches a payment by id."
  @spec get(Client.t(), HTTP.id(), keyword()) :: HTTP.response()
  def get(%Client{} = client, payment_id, opts \\ []) do
    HTTP.get(client, "/v1/payments/#{HTTP.encode_path_param(payment_id)}", nil, opts)
  end

  @doc "Creates a payment from `payment_data`."
  @spec create(Client.t(), map(), keyword()) :: HTTP.response()
  def create(%Client{} = client, payment_data, opts \\ []) do
    HTTP.post(client, "/v1/payments/", payment_data, opts)
  end

  @doc """
  Captures a previously authorized payment.

  Omit `amount` to capture the full authorized amount, or pass a smaller one for
  a partial capture. This is the named form of the `update/4` call MercadoPago
  documents for capture; `update/4` remains available for any other field.
  """
  @spec capture(Client.t(), HTTP.id(), number() | nil, keyword()) :: HTTP.response()
  def capture(%Client{} = client, payment_id, amount \\ nil, opts \\ []) do
    body = if amount, do: %{capture: true, transaction_amount: amount}, else: %{capture: true}

    update(client, payment_id, body, opts)
  end

  @doc "Updates a payment (e.g. to capture or cancel it)."
  @spec update(Client.t(), HTTP.id(), map(), keyword()) :: HTTP.response()
  def update(%Client{} = client, payment_id, payment_data, opts \\ []) do
    HTTP.put(client, "/v1/payments/#{HTTP.encode_path_param(payment_id)}", payment_data, opts)
  end
end
