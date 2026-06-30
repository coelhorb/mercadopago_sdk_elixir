defmodule Mercadopago do
  @moduledoc """
  Entry point for the MercadoPago Elixir SDK.

  Create a client with `new/2`, then pass it to any resource module:

      client = Mercadopago.new("YOUR_ACCESS_TOKEN")
      {:ok, %{status: 201, response: payment}} = Mercadopago.Payment.create(client, payment_data)

  Per-call token override:

      Mercadopago.Payment.get(client, id, access_token: "OTHER_TOKEN")
  """

  alias Mercadopago.Client

  @doc """
  Creates a new SDK client.

  ## Options

    * `:timeout` - HTTP timeout in milliseconds (default: 60_000)
    * `:max_retries` - max retries for GET on transient errors (default: 3)
    * `:custom_headers` - extra headers merged into every request (default: %{})
    * `:corporation_id` - MercadoPago x-corporation-id header
    * `:integrator_id` - MercadoPago x-integrator-id header
    * `:platform_id` - MercadoPago x-platform-id header
    * `:plug` - Req plug for testing (e.g. `{Req.Test, :my_stub}`); nil in production
  """
  @spec new(String.t(), keyword()) :: Client.t()
  def new(access_token, opts \\ []) when is_binary(access_token) do
    %Client{
      access_token: access_token,
      plug: opts[:plug],
      timeout: Keyword.get(opts, :timeout, 60_000),
      max_retries: Keyword.get(opts, :max_retries, 3),
      custom_headers: Keyword.get(opts, :custom_headers, %{}),
      corporation_id: opts[:corporation_id],
      integrator_id: opts[:integrator_id],
      platform_id: opts[:platform_id]
    }
  end
end
