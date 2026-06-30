defmodule Mercadopago.Card do
  @moduledoc "Stored cards linked to a customer."

  alias Mercadopago.{Client, HTTP}

  @doc "Fetches a stored card by id for the given customer."
  @spec get(Client.t(), String.t(), String.t(), keyword()) :: HTTP.response()
  def get(%Client{} = client, customer_id, card_id, opts \\ []) do
    HTTP.get(client, "/v1/customers/#{customer_id}/cards/#{card_id}", nil, opts)
  end

  @doc "Stores a new card for the given customer."
  @spec create(Client.t(), String.t(), map(), keyword()) :: HTTP.response()
  def create(%Client{} = client, customer_id, card_data, opts \\ []) do
    HTTP.post(client, "/v1/customers/#{customer_id}/cards/", card_data, opts)
  end

  @doc "Deletes a stored card from the given customer."
  @spec delete(Client.t(), String.t(), String.t(), keyword()) :: HTTP.response()
  def delete(%Client{} = client, customer_id, card_id, opts \\ []) do
    HTTP.delete(client, "/v1/customers/#{customer_id}/cards/#{card_id}", opts)
  end

  @doc "Lists all stored cards for the given customer."
  @spec list(Client.t(), String.t(), keyword()) :: HTTP.response()
  def list(%Client{} = client, customer_id, opts \\ []) do
    HTTP.get(client, "/v1/customers/#{customer_id}/cards", nil, opts)
  end
end
