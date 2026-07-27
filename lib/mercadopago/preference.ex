defmodule Mercadopago.Preference do
  @moduledoc """
  Checkout Pro payment preferences.

  This is the hosted flow: create a preference, then redirect the buyer to the
  `init_point` MercadoPago returns. For the Checkout API — where you own the
  payment form — see `Mercadopago.Order` and `Mercadopago.Payment`.
  """

  alias Mercadopago.{Client, HTTP}

  @doc "Fetches a preference by id."
  @spec get(Client.t(), HTTP.id(), keyword()) :: HTTP.response()
  def get(%Client{} = client, preference_id, opts \\ []) do
    HTTP.get(client, "/checkout/preferences/#{HTTP.encode_path_param(preference_id)}", nil, opts)
  end

  @doc "Creates a preference from `preference_data`."
  @spec create(Client.t(), map(), keyword()) :: HTTP.response()
  def create(%Client{} = client, preference_data, opts \\ []) do
    HTTP.post(client, "/checkout/preferences", preference_data, opts)
  end

  @doc "Updates a preference."
  @spec update(Client.t(), HTTP.id(), map(), keyword()) :: HTTP.response()
  def update(%Client{} = client, preference_id, preference_data, opts \\ []) do
    HTTP.put(
      client,
      "/checkout/preferences/#{HTTP.encode_path_param(preference_id)}",
      preference_data,
      opts
    )
  end
end
