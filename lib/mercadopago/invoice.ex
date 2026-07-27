defmodule Mercadopago.Invoice do
  @moduledoc "Subscription billing invoice retrieval."

  alias Mercadopago.{Client, HTTP}

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
end
