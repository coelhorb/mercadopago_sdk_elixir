defmodule Mercadopago do
  @moduledoc """
  Entry point for the MercadoPago Elixir SDK.

  Create a client with `new/2`, then pass it to any resource module:

      client = Mercadopago.new("YOUR_ACCESS_TOKEN")
      {:ok, %{status: 201, response: payment}} = Mercadopago.Payment.create(client, payment_data)

  Every resource call accepts per-call options that override the client
  configuration for that request only:

      Mercadopago.Payment.get(client, id, access_token: "OTHER_TOKEN")
      Mercadopago.Payment.create(client, data, custom_headers: %{"x-idempotency-key" => key})
      Mercadopago.Payment.search(client, filters, timeout: 5_000, max_retries: 1)

  ## Handling errors

  Every completed request is `{:ok, %{status: _, response: _}}` — a 404 included —
  and `{:error, reason}` is reserved for transport failures. Pipe through
  `Mercadopago.HTTP.unwrap/1` when you would rather branch on `{:ok, _}` /
  `{:error, %Mercadopago.Error{}}` than on the status code:

      case client |> Mercadopago.Payment.get(id) |> Mercadopago.HTTP.unwrap() do
        {:ok, payment} -> payment
        {:error, %Mercadopago.Error{status: 404}} -> nil
      end
  """

  alias Mercadopago.Client

  @doc """
  Creates a new SDK client.

  Pass `nil` as the token only to bootstrap the OAuth authorization-code flow,
  where no token exists yet — the `Authorization` header is then omitted rather
  than sent empty. See `Mercadopago.OAuth`.

  ## Options

    * `:timeout` - HTTP timeout in milliseconds (default: 60_000)
    * `:max_retries` - total GET attempts on transient errors (default: 3, i.e.
      the first attempt plus two retries)
    * `:retry_delay` - base backoff in milliseconds, doubled on each retry and
      jittered (default: 1_000)
    * `:max_retry_delay` - ceiling for the backoff, also capping a `Retry-After`
      sent by the server, in milliseconds (default: 8_000)
    * `:custom_headers` - extra headers merged into every request, overriding
      generated headers case-insensitively (default: %{})
    * `:corporation_id` - MercadoPago x-corporation-id header
    * `:integrator_id` - MercadoPago x-integrator-id header
    * `:platform_id` - MercadoPago x-platform-id header
    * `:finch` - name of a Finch pool started by the host application, for
      dedicated connection pooling; nil uses Req's default pool
    * `:plug` - Req plug for testing (e.g. `{Req.Test, :my_stub}`); nil in production
  """
  @spec new(String.t() | nil, keyword()) :: Client.t()
  def new(access_token, opts \\ []) when is_binary(access_token) or is_nil(access_token) do
    %Client{
      access_token: access_token,
      plug: opts[:plug],
      finch: opts[:finch],
      timeout: Keyword.get(opts, :timeout, 60_000),
      max_retries: Keyword.get(opts, :max_retries, 3),
      retry_delay: Keyword.get(opts, :retry_delay, 1_000),
      max_retry_delay: Keyword.get(opts, :max_retry_delay, 8_000),
      custom_headers: Keyword.get(opts, :custom_headers, %{}),
      corporation_id: opts[:corporation_id],
      integrator_id: opts[:integrator_id],
      platform_id: opts[:platform_id]
    }
  end
end
