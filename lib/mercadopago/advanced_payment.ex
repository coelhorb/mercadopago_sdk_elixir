defmodule Mercadopago.AdvancedPayment do
  @moduledoc "Split-payment operations for marketplace scenarios."

  alias Mercadopago.{Client, HTTP}

  @doc "Searches advanced payments matching `filters` (query-string parameters)."
  @spec search(Client.t(), map() | nil, keyword()) :: HTTP.response()
  def search(%Client{} = client, filters \\ nil, opts \\ []) do
    HTTP.get(client, "/v1/advanced_payments/search", filters, opts)
  end

  @doc "Fetches an advanced payment by id."
  @spec get(Client.t(), String.t(), keyword()) :: HTTP.response()
  def get(%Client{} = client, advanced_payment_id, opts \\ []) do
    HTTP.get(client, "/v1/advanced_payments/#{advanced_payment_id}", nil, opts)
  end

  @doc "Creates an advanced payment from `advanced_payment_data`."
  @spec create(Client.t(), map(), keyword()) :: HTTP.response()
  def create(%Client{} = client, advanced_payment_data, opts \\ []) do
    HTTP.post(client, "/v1/advanced_payments", advanced_payment_data, opts)
  end

  @doc "Captures an authorized advanced payment."
  @spec capture(Client.t(), String.t(), keyword()) :: HTTP.response()
  def capture(%Client{} = client, advanced_payment_id, opts \\ []) do
    HTTP.put(client, "/v1/advanced_payments/#{advanced_payment_id}", %{capture: true}, opts)
  end

  @doc "Updates an advanced payment."
  @spec update(Client.t(), String.t(), map(), keyword()) :: HTTP.response()
  def update(%Client{} = client, advanced_payment_id, advanced_payment_data, opts \\ []) do
    HTTP.put(client, "/v1/advanced_payments/#{advanced_payment_id}", advanced_payment_data, opts)
  end

  @doc "Cancels an advanced payment."
  @spec cancel(Client.t(), String.t(), keyword()) :: HTTP.response()
  def cancel(%Client{} = client, advanced_payment_id, opts \\ []) do
    HTTP.put(client, "/v1/advanced_payments/#{advanced_payment_id}", %{status: "cancelled"}, opts)
  end

  @doc "Reschedules the money release date of an advanced payment."
  @spec update_release_date(Client.t(), String.t(), String.t(), keyword()) :: HTTP.response()
  def update_release_date(%Client{} = client, advanced_payment_id, release_date, opts \\ []) do
    HTTP.post(
      client,
      "/v1/advanced_payments/#{advanced_payment_id}/disburses",
      %{money_release_date: release_date},
      opts
    )
  end
end
