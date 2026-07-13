defmodule Mercadopago.Resource do
  @moduledoc """
  Internal contract for resources that expose the full CRUD API.

  It keeps the `create`, `get`, `search`, and `update` callbacks consistent at
  compile time. Implementing modules represent distinct API resources and are
  not intended to be interchangeable at runtime.
  """

  alias Mercadopago.{Client, HTTP}

  @callback create(Client.t(), map(), keyword()) :: HTTP.response()
  @callback get(Client.t(), String.t(), keyword()) :: HTTP.response()
  @callback search(Client.t(), map() | nil, keyword()) :: HTTP.response()
  @callback update(Client.t(), String.t(), map(), keyword()) :: HTTP.response()
end
