defmodule Mercadopago.Error do
  @moduledoc """
  An API error response, produced by `Mercadopago.HTTP.unwrap/1`.

  The SDK's own functions never return this: they report every completed
  response as `{:ok, %{status: _, response: _}}`, errors included. Use it when
  you would rather branch on `{:ok, _}` / `{:error, _}` than on the status code.
  """

  defexception [:status, :response, :cause, message: "MercadoPago API error"]

  @type t :: %__MODULE__{
          status: non_neg_integer(),
          response: map() | list() | binary() | nil,
          cause: term(),
          message: String.t()
        }

  @doc """
  Builds an error from a status and a decoded response body.

  MercadoPago is inconsistent about which key carries the human-readable text,
  so `message` falls back through `"message"`, `"error"` and finally a generic
  string naming the status. The untouched body is always kept in `:response`.
  """
  @spec new(non_neg_integer(), map() | list() | binary() | nil) :: t()
  def new(status, response) do
    %__MODULE__{
      status: status,
      response: response,
      cause: extract(response, "cause"),
      message: message_for(status, response)
    }
  end

  defp message_for(status, response) do
    case extract(response, "message") || extract(response, "error") do
      nil -> "MercadoPago API error (HTTP #{status})"
      text when is_binary(text) -> "#{text} (HTTP #{status})"
      other -> "#{inspect(other)} (HTTP #{status})"
    end
  end

  defp extract(response, key) when is_map(response), do: Map.get(response, key)
  defp extract(_response, _key), do: nil
end
