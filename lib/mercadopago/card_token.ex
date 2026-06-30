defmodule Mercadopago.CardToken do
  @moduledoc "Server-side card tokenisation."

  alias Mercadopago.{Client, HTTP}

  @doc "Fetches a card token by id."
  @spec get(Client.t(), String.t(), keyword()) :: HTTP.response()
  def get(%Client{} = client, card_token_id, opts \\ []) do
    HTTP.get(client, "/v1/card_tokens/#{card_token_id}", nil, opts)
  end

  @doc "Creates a card token from `card_token_data`."
  @spec create(Client.t(), map(), keyword()) :: HTTP.response()
  def create(%Client{} = client, card_token_data, opts \\ []) do
    HTTP.post(client, "/v1/card_tokens", card_token_data, opts)
  end
end
