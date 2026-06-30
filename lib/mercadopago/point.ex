defmodule Mercadopago.Point do
  @moduledoc "In-person payment intents on MercadoPago Point (POS) devices."

  alias Mercadopago.{Client, HTTP}

  @doc "Lists Point devices matching `filters` (query-string parameters)."
  @spec get_devices(Client.t(), map() | nil, keyword()) :: HTTP.response()
  def get_devices(%Client{} = client, filters \\ nil, opts \\ []) do
    HTTP.get(client, "/point/integration-api/devices", filters, opts)
  end

  @doc "Creates a payment intent on the given Point device."
  @spec create(Client.t(), String.t(), map(), keyword()) :: HTTP.response()
  def create(%Client{} = client, device_id, payment_intent_data, opts \\ []) do
    HTTP.post(
      client,
      "/point/integration-api/devices/#{device_id}/payment-intents",
      payment_intent_data,
      opts
    )
  end

  @doc "Fetches a payment intent by id."
  @spec get(Client.t(), String.t(), keyword()) :: HTTP.response()
  def get(%Client{} = client, payment_intent_id, opts \\ []) do
    HTTP.get(client, "/point/integration-api/payment-intents/#{payment_intent_id}", nil, opts)
  end

  @doc "Cancels a payment intent on the given device. Uses DELETE, mirroring the Ruby SDK."
  @spec cancel(Client.t(), String.t(), String.t(), keyword()) :: HTTP.response()
  def cancel(%Client{} = client, device_id, payment_intent_id, opts \\ []) do
    HTTP.delete(
      client,
      "/point/integration-api/devices/#{device_id}/payment-intents/#{payment_intent_id}",
      opts
    )
  end
end
