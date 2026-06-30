defmodule Mercadopago.Preference do
  @moduledoc "Checkout Pro payment preferences."

  alias Mercadopago.{Client, HTTP}

  @doc "Fetches a preference by id."
  @spec get(Client.t(), String.t(), keyword()) :: HTTP.response()
  def get(%Client{} = client, preference_id, opts \\ []) do
    HTTP.get(client, "/checkout/preferences/#{preference_id}", nil, opts)
  end

  @doc "Creates a preference from `preference_data`."
  @spec create(Client.t(), map(), keyword()) :: HTTP.response()
  def create(%Client{} = client, preference_data, opts \\ []) do
    HTTP.post(client, "/checkout/preferences", preference_data, opts)
  end

  @doc "Updates a preference."
  @spec update(Client.t(), String.t(), map(), keyword()) :: HTTP.response()
  def update(%Client{} = client, preference_id, preference_data, opts \\ []) do
    HTTP.put(client, "/checkout/preferences/#{preference_id}", preference_data, opts)
  end
end
