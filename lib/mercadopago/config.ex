defmodule Mercadopago.Config do
  @moduledoc "SDK-wide constants: API URLs, version, and tracking identifiers."

  @version "0.1.0"
  @api_base_url "https://api.mercadopago.com"
  @auth_base_url "https://auth.mercadopago.com/authorization"
  @product_id "bc32a7vtrpp001u8nhjg"

  def version, do: @version
  def api_base_url, do: @api_base_url
  def auth_base_url, do: @auth_base_url
  def product_id, do: @product_id
  def user_agent, do: "MercadoPago Elixir SDK v#{@version}"
  def tracking_id, do: "platform:#{System.version()},type:SDK#{@version},so;"
end
