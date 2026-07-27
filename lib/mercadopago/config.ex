defmodule Mercadopago.Config do
  @moduledoc "SDK-wide constants: API URLs, version, and tracking identifiers."

  # Single source of truth: the version declared in mix.exs, read at compile time.
  @version Mix.Project.config()[:version]
  @api_base_url "https://api.mercadopago.com"
  @auth_base_url "https://auth.mercadopago.com/authorization"
  @product_id "bc32a7vtrpp001u8nhjg"
  @user_agent "MercadoPago Elixir SDK v#{@version}"
  @tracking_id "platform:#{System.version()},type:SDK#{@version},so;"

  def version, do: @version
  def api_base_url, do: @api_base_url
  def auth_base_url, do: @auth_base_url
  def product_id, do: @product_id
  def user_agent, do: @user_agent
  def tracking_id, do: @tracking_id
end
