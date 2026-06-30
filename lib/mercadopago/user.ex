defmodule Mercadopago.User do
  @moduledoc "Retrieves the authenticated user's profile."

  alias Mercadopago.{Client, HTTP}

  @doc "Fetches the profile of the authenticated user."
  @spec get(Client.t(), keyword()) :: HTTP.response()
  def get(%Client{} = client, opts \\ []) do
    HTTP.get(client, "/users/me", nil, opts)
  end
end
