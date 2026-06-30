defmodule Mercadopago.Customer do
  @moduledoc "Customer record management."

  alias Mercadopago.{Client, HTTP}

  @doc "Searches customers matching `filters` (query-string parameters)."
  @spec search(Client.t(), map() | nil, keyword()) :: HTTP.response()
  def search(%Client{} = client, filters \\ nil, opts \\ []) do
    HTTP.get(client, "/v1/customers/search", filters, opts)
  end

  @doc "Fetches a customer by id."
  @spec get(Client.t(), String.t(), keyword()) :: HTTP.response()
  def get(%Client{} = client, customer_id, opts \\ []) do
    HTTP.get(client, "/v1/customers/#{customer_id}", nil, opts)
  end

  @doc "Creates a customer from `customer_data`."
  @spec create(Client.t(), map(), keyword()) :: HTTP.response()
  def create(%Client{} = client, customer_data, opts \\ []) do
    HTTP.post(client, "/v1/customers", customer_data, opts)
  end

  @doc "Updates a customer."
  @spec update(Client.t(), String.t(), map(), keyword()) :: HTTP.response()
  def update(%Client{} = client, customer_id, customer_data, opts \\ []) do
    HTTP.put(client, "/v1/customers/#{customer_id}", customer_data, opts)
  end

  @doc "Deletes a customer by id."
  @spec delete(Client.t(), String.t(), keyword()) :: HTTP.response()
  def delete(%Client{} = client, customer_id, opts \\ []) do
    HTTP.delete(client, "/v1/customers/#{customer_id}", opts)
  end
end
