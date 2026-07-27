defmodule Mercadopago.Payment do
  @moduledoc "Payment operations via the Checkout API."

  alias Mercadopago.{Client, HTTP}

  @doc "Searches payments matching `filters` (query-string parameters)."
  @spec search(Client.t(), map() | nil, keyword()) :: HTTP.response()
  def search(%Client{} = client, filters \\ nil, opts \\ []) do
    HTTP.get(client, "/v1/payments/search", filters, opts)
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

  @doc "Updates a payment (e.g. to capture or cancel it)."
  @spec update(Client.t(), HTTP.id(), map(), keyword()) :: HTTP.response()
  def update(%Client{} = client, payment_id, payment_data, opts \\ []) do
    HTTP.put(client, "/v1/payments/#{HTTP.encode_path_param(payment_id)}", payment_data, opts)
  end
end
