defmodule Mercadopago.Order do
  @moduledoc """
  Order lifecycle: create, process, capture, refund, cancel, and search.

  These endpoints are the **Checkout API via Orders**, which MercadoPago
  documents separately from Checkout Pro. If you want the hosted flow where the
  buyer is redirected to MercadoPago, you want `Mercadopago.Preference` instead —
  the similar shape of the two payloads makes them easy to confuse.
  """

  alias Mercadopago.{Client, HTTP, Pagination}

  @doc "Creates an order from `order_data`."
  @spec create(Client.t(), map(), keyword()) :: HTTP.response()
  def create(%Client{} = client, order_data, opts \\ []) do
    HTTP.post(client, "/v1/orders", order_data, opts)
  end

  @doc """
  Creates an online order processed in stages (Checkout API via Orders).

  Convenience wrapper over `create/3` that applies the two-step defaults:
  `type` `"online"` and `processing_mode` `"manual"` when omitted. Follow it with
  `process/3` to settle the order. If those fields are provided (atom or string
  key), they must already match this flow; otherwise an `ArgumentError` is raised.

  This is *not* Checkout Pro. For the hosted Checkout Pro flow, create a payment
  preference with `Mercadopago.Preference.create/3` instead.
  """
  @spec create_online(Client.t(), map(), keyword()) :: HTTP.response()
  def create_online(%Client{} = client, order_data, opts \\ []) when is_map(order_data) do
    online_data =
      order_data
      |> put_online_default!(:type, "online")
      |> put_online_default!(:processing_mode, "manual")

    HTTP.post(client, "/v1/orders", online_data, opts)
  end

  @doc """
  Deprecated alias for `create_online/3`.

  The name is inherited from the Ruby SDK but is a misnomer: `POST /v1/orders`
  with `type: "online"` is the Checkout API (via Orders), which MercadoPago
  documents separately from Checkout Pro. Checkout Pro lives in
  `Mercadopago.Preference`.
  """
  @deprecated "Use create_online/3, or Mercadopago.Preference.create/3 for Checkout Pro"
  @spec create_checkout_pro(Client.t(), map(), keyword()) :: HTTP.response()
  def create_checkout_pro(%Client{} = client, order_data, opts \\ []) do
    create_online(client, order_data, opts)
  end

  @doc "Fetches an order by id."
  @spec get(Client.t(), HTTP.id(), keyword()) :: HTTP.response()
  def get(%Client{} = client, order_id, opts \\ []) do
    HTTP.get(client, "/v1/orders/#{HTTP.encode_path_param(order_id)}", nil, opts)
  end

  @doc "Processes a previously created order."
  @spec process(Client.t(), HTTP.id(), keyword()) :: HTTP.response()
  def process(%Client{} = client, order_id, opts \\ []) do
    HTTP.post(client, "/v1/orders/#{HTTP.encode_path_param(order_id)}/process", nil, opts)
  end

  @doc "Refunds an order, fully or partially via `refund_data`."
  @spec refund(Client.t(), HTTP.id(), map() | nil, keyword()) :: HTTP.response()
  def refund(%Client{} = client, order_id, refund_data \\ nil, opts \\ []) do
    HTTP.post(client, "/v1/orders/#{HTTP.encode_path_param(order_id)}/refund", refund_data, opts)
  end

  @doc "Cancels an order."
  @spec cancel(Client.t(), HTTP.id(), keyword()) :: HTTP.response()
  def cancel(%Client{} = client, order_id, opts \\ []) do
    HTTP.post(client, "/v1/orders/#{HTTP.encode_path_param(order_id)}/cancel", nil, opts)
  end

  @doc "Captures an authorized order."
  @spec capture(Client.t(), HTTP.id(), keyword()) :: HTTP.response()
  def capture(%Client{} = client, order_id, opts \\ []) do
    HTTP.post(client, "/v1/orders/#{HTTP.encode_path_param(order_id)}/capture", nil, opts)
  end

  @doc "Searches orders matching `filters` (query-string parameters)."
  @spec search(Client.t(), map() | nil, keyword()) :: HTTP.response()
  def search(%Client{} = client, filters \\ nil, opts \\ []) do
    HTTP.get(client, "/v1/orders", filters, opts)
  end

  @doc """
  Streams every result of `search/3`, fetching each page as it is consumed.

  See `Mercadopago.Pagination.stream/3` for the options and for how failures are
  reported.
  """
  @spec search_stream(Client.t(), map() | nil, keyword()) :: Enumerable.t()
  def search_stream(%Client{} = client, filters \\ nil, opts \\ []) do
    Pagination.stream(&search(client, &1, opts), filters, opts)
  end

  # The field may come in with an atom or a string key. When absent, the default
  # is applied using the key style the caller already uses, so the map does not
  # end up with a mix of atom and string keys; when present, it must already match.
  defp put_online_default!(order_data, field, expected) do
    case fetch_either(order_data, field, Atom.to_string(field)) do
      :error -> Map.put(order_data, default_key(order_data, field), expected)
      {:ok, ^expected} -> order_data
      {:ok, _other} -> raise ArgumentError, "Param #{field} must be #{expected}"
    end
  end

  defp default_key(order_data, field) do
    if Enum.any?(Map.keys(order_data), &is_binary/1) do
      Atom.to_string(field)
    else
      field
    end
  end

  defp fetch_either(map, atom_key, string_key) do
    case Map.fetch(map, atom_key) do
      :error -> Map.fetch(map, string_key)
      {:ok, _value} = found -> found
    end
  end
end
