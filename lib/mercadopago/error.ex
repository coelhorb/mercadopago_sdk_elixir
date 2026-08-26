defmodule Mercadopago.Error do
  @moduledoc """
  An API error response, produced by `Mercadopago.HTTP.unwrap/1` and raised by
  `Mercadopago.Pagination.stream/3`.

  The SDK's own resource functions never return this: they report every
  completed response as `{:ok, %{status: _, response: _}}`, errors included. Use
  it when you would rather branch on `{:ok, _}` / `{:error, _}` than on the
  status code.

  Match on `:kind` rather than the raw status when you care about the class of
  failure:

      case client |> Mercadopago.Payment.get(id) |> Mercadopago.HTTP.unwrap() do
        {:ok, payment} -> payment
        {:error, %Mercadopago.Error{kind: :not_found}} -> nil
        {:error, %Mercadopago.Error{kind: :rate_limit, retry_after: seconds}} -> back_off(seconds)
        {:error, %Mercadopago.Error{kind: :server, request_id: id}} -> escalate(id)
      end
  """

  defexception [
    :status,
    :kind,
    :response,
    :cause,
    :request_id,
    :retry_after,
    message: "MercadoPago API error"
  ]

  @typedoc """
  The class of failure, derived from the HTTP status. `:api` covers any status
  the API uses that has no more specific meaning.
  """
  @type kind ::
          :bad_request
          | :authentication
          | :payment
          | :forbidden
          | :not_found
          | :idempotency
          | :validation
          | :resource_locked
          | :dependency
          | :rate_limit
          | :server
          | :api

  @type t :: %__MODULE__{
          status: non_neg_integer(),
          kind: kind(),
          response: map() | list() | binary() | nil,
          cause: term(),
          request_id: String.t() | nil,
          retry_after: non_neg_integer() | nil,
          message: String.t()
        }

  # Same status-to-class mapping the reference Ruby SDK uses for its exception
  # hierarchy (lib/mercadopago/errors/exceptions.rb).
  @kinds %{
    400 => :bad_request,
    401 => :authentication,
    402 => :payment,
    403 => :forbidden,
    404 => :not_found,
    409 => :idempotency,
    422 => :validation,
    423 => :resource_locked,
    424 => :dependency,
    429 => :rate_limit
  }

  @doc """
  Builds an error from a status and a decoded response body.

  MercadoPago is inconsistent about which key carries the human-readable text,
  so `message` falls back through `"message"`, `"error"` and finally a generic
  string naming the status. The untouched body is always kept in `:response`.

  ## Options

    * `:request_id` - the `x-request-id` the API answered with, the identifier
      MercadoPago support asks for
    * `:retry_after` - seconds from the `Retry-After` header, when it sent one

  """
  @spec new(non_neg_integer(), map() | list() | binary() | nil, keyword()) :: t()
  def new(status, response, opts \\ []) do
    %__MODULE__{
      status: status,
      kind: kind_for(status),
      response: response,
      cause: extract(response, "cause"),
      request_id: opts[:request_id],
      retry_after: opts[:retry_after],
      message: message_for(status, response)
    }
  end

  @doc "The class of failure for an HTTP status. See `t:kind/0`."
  @spec kind_for(non_neg_integer()) :: kind()
  def kind_for(status) do
    case @kinds do
      %{^status => kind} -> kind
      _other when status >= 500 -> :server
      _other -> :api
    end
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
