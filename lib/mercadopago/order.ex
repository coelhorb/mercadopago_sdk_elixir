defmodule Mercadopago.Order do
  @moduledoc "Order lifecycle: create, process, capture, refund, cancel, and search."

  alias Mercadopago.{Client, HTTP}

  @doc "Creates an order from `order_data`."
  @spec create(Client.t(), map(), keyword()) :: HTTP.response()
  def create(%Client{} = client, order_data, opts \\ []) do
    HTTP.post(client, "/v1/orders", order_data, opts)
  end

  @doc """
  Creates a Checkout Pro order.

  Convenience wrapper over `create/3` that applies the Checkout Pro Orders API
  defaults: `type` `"online"` and `processing_mode` `"manual"` when omitted.
  If those fields are provided (atom or string key), they must already match
  the Checkout Pro flow; otherwise an `ArgumentError` is raised.
  """
  @spec create_checkout_pro(Client.t(), map(), keyword()) :: HTTP.response()
  def create_checkout_pro(%Client{} = client, order_data, opts \\ []) when is_map(order_data) do
    checkout_pro_data =
      order_data
      |> put_checkout_pro_default!(:type, "online")
      |> put_checkout_pro_default!(:processing_mode, "manual")

    HTTP.post(client, "/v1/orders", checkout_pro_data, opts)
  end

  @doc "Fetches an order by id."
  @spec get(Client.t(), String.t(), keyword()) :: HTTP.response()
  def get(%Client{} = client, order_id, opts \\ []) do
    HTTP.get(client, "/v1/orders/#{order_id}", nil, opts)
  end

  @doc "Processes a previously created order."
  @spec process(Client.t(), String.t(), keyword()) :: HTTP.response()
  def process(%Client{} = client, order_id, opts \\ []) do
    HTTP.post(client, "/v1/orders/#{order_id}/process", nil, opts)
  end

  @doc "Refunds an order, fully or partially via `refund_data`."
  @spec refund(Client.t(), String.t(), map() | nil, keyword()) :: HTTP.response()
  def refund(%Client{} = client, order_id, refund_data \\ nil, opts \\ []) do
    HTTP.post(client, "/v1/orders/#{order_id}/refund", refund_data, opts)
  end

  @doc "Cancels an order."
  @spec cancel(Client.t(), String.t(), keyword()) :: HTTP.response()
  def cancel(%Client{} = client, order_id, opts \\ []) do
    HTTP.post(client, "/v1/orders/#{order_id}/cancel", nil, opts)
  end

  @doc "Captures an authorized order."
  @spec capture(Client.t(), String.t(), keyword()) :: HTTP.response()
  def capture(%Client{} = client, order_id, opts \\ []) do
    HTTP.post(client, "/v1/orders/#{order_id}/capture", nil, opts)
  end

  @doc "Searches orders matching `filters` (query-string parameters)."
  @spec search(Client.t(), map() | nil, keyword()) :: HTTP.response()
  def search(%Client{} = client, filters \\ nil, opts \\ []) do
    HTTP.get(client, "/v1/orders", filters, opts)
  end

  defp put_checkout_pro_default!(order_data, field, expected) do
    value = Map.get(order_data, field, Map.get(order_data, to_string(field)))

    cond do
      not (is_nil(value) or value == expected) ->
        raise ArgumentError, "Param #{field} must be #{expected}"

      Map.has_key?(order_data, field) or Map.has_key?(order_data, to_string(field)) ->
        order_data

      true ->
        Map.put(order_data, field, expected)
    end
  end
end
