defmodule Mercadopago.Card do
  @moduledoc "Stored cards linked to a customer. Customers themselves live in `Mercadopago.Customer`."

  alias Mercadopago.{Client, HTTP}

  @doc "Fetches a stored card by id for the given customer."
  @spec get(Client.t(), HTTP.id(), HTTP.id(), keyword()) :: HTTP.response()
  def get(%Client{} = client, customer_id, card_id, opts \\ []) do
    HTTP.get(
      client,
      "/v1/customers/#{HTTP.encode_path_param(customer_id)}/cards/#{HTTP.encode_path_param(card_id)}",
      nil,
      opts
    )
  end

  @doc "Stores a new card for the given customer."
  @spec create(Client.t(), HTTP.id(), map(), keyword()) :: HTTP.response()
  def create(%Client{} = client, customer_id, card_data, opts \\ []) do
    HTTP.post(
      client,
      "/v1/customers/#{HTTP.encode_path_param(customer_id)}/cards/",
      card_data,
      opts
    )
  end

  @doc "Updates a stored card for the given customer."
  @spec update(Client.t(), HTTP.id(), HTTP.id(), map(), keyword()) :: HTTP.response()
  def update(%Client{} = client, customer_id, card_id, card_data, opts \\ []) do
    HTTP.put(
      client,
      "/v1/customers/#{HTTP.encode_path_param(customer_id)}/cards/#{HTTP.encode_path_param(card_id)}",
      card_data,
      opts
    )
  end

  @doc "Deletes a stored card from the given customer."
  @spec delete(Client.t(), HTTP.id(), HTTP.id(), keyword()) :: HTTP.response()
  def delete(%Client{} = client, customer_id, card_id, opts \\ []) do
    HTTP.delete(
      client,
      "/v1/customers/#{HTTP.encode_path_param(customer_id)}/cards/#{HTTP.encode_path_param(card_id)}",
      opts
    )
  end

  @doc "Lists all stored cards for the given customer."
  @spec list(Client.t(), HTTP.id(), keyword()) :: HTTP.response()
  def list(%Client{} = client, customer_id, opts \\ []) do
    HTTP.get(client, "/v1/customers/#{HTTP.encode_path_param(customer_id)}/cards", nil, opts)
  end
end
