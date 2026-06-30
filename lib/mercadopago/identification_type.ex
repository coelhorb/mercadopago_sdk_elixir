defmodule Mercadopago.IdentificationType do
  @moduledoc "Lists supported ID document types per country."

  alias Mercadopago.{Client, HTTP}

  @doc "Lists the supported identification (document) types."
  @spec get(Client.t(), keyword()) :: HTTP.response()
  def get(%Client{} = client, opts \\ []) do
    HTTP.get(client, "/v1/identification_types", nil, opts)
  end
end
