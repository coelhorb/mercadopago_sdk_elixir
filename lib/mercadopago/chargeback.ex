defmodule Mercadopago.Chargeback do
  @moduledoc "Payment dispute (chargeback) retrieval and search."

  alias Mercadopago.{Client, HTTP}

  @doc "Fetches a chargeback by id."
  @spec get(Client.t(), String.t(), keyword()) :: HTTP.response()
  def get(%Client{} = client, chargeback_id, opts \\ []) do
    HTTP.get(client, "/v1/chargebacks/#{chargeback_id}", nil, opts)
  end

  @doc "Searches chargebacks matching `filters` (query-string parameters)."
  @spec search(Client.t(), map() | nil, keyword()) :: HTTP.response()
  def search(%Client{} = client, filters \\ nil, opts \\ []) do
    HTTP.get(client, "/v1/chargebacks/search", filters, opts)
  end
end
