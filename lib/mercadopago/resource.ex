defmodule Mercadopago.Resource do
  @moduledoc "Behaviour shared by full CRUD resources (create, get, search, update)."

  alias Mercadopago.{Client, HTTP}

  @callback create(Client.t(), map(), keyword()) :: HTTP.response()
  @callback get(Client.t(), String.t(), keyword()) :: HTTP.response()
  @callback search(Client.t(), map() | nil, keyword()) :: HTTP.response()
  @callback update(Client.t(), String.t(), map(), keyword()) :: HTTP.response()
end
