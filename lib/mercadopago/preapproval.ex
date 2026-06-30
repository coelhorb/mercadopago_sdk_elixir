defmodule Mercadopago.Preapproval do
  @moduledoc "Recurring subscription management."

  @behaviour Mercadopago.Resource

  alias Mercadopago.{Client, HTTP}

  @doc "Searches preapprovals matching `filters` (query-string parameters)."
  @spec search(Client.t(), map() | nil, keyword()) :: HTTP.response()
  def search(%Client{} = client, filters \\ nil, opts \\ []) do
    HTTP.get(client, "/preapproval/search", filters, opts)
  end

  @doc "Fetches a preapproval by id."
  @spec get(Client.t(), String.t(), keyword()) :: HTTP.response()
  def get(%Client{} = client, preapproval_id, opts \\ []) do
    HTTP.get(client, "/preapproval/#{preapproval_id}", nil, opts)
  end

  @doc "Creates a preapproval from `preapproval_data`."
  @spec create(Client.t(), map(), keyword()) :: HTTP.response()
  def create(%Client{} = client, preapproval_data, opts \\ []) do
    HTTP.post(client, "/preapproval/", preapproval_data, opts)
  end

  @doc "Updates a preapproval."
  @spec update(Client.t(), String.t(), map(), keyword()) :: HTTP.response()
  def update(%Client{} = client, preapproval_id, preapproval_data, opts \\ []) do
    HTTP.put(client, "/preapproval/#{preapproval_id}", preapproval_data, opts)
  end
end
