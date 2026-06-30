defmodule Mercadopago.OAuth do
  @moduledoc "OAuth 2.0 authorization code flow for marketplace/platform integrations."

  alias Mercadopago.{Client, Config, HTTP}

  @doc "Builds the authorization URL to redirect the seller to. Does not make an HTTP call."
  @spec get_authorization_url(String.t(), String.t(), String.t()) :: String.t()
  def get_authorization_url(app_id, redirect_uri, random_id) do
    params =
      URI.encode_query(%{
        client_id: app_id,
        response_type: "code",
        platform_id: "mp",
        state: random_id,
        redirect_uri: redirect_uri
      })

    "#{Config.auth_base_url()}?#{params}"
  end

  @doc "Exchanges an authorization code for an access token (grant_type: authorization_code)."
  @spec create(Client.t(), map(), keyword()) :: HTTP.response()
  def create(%Client{} = client, oauth_data, opts \\ []) do
    HTTP.post(client, "/oauth/token", oauth_data, opts)
  end

  @doc "Refreshes an expired access token (grant_type: refresh_token)."
  @spec refresh(Client.t(), map(), keyword()) :: HTTP.response()
  def refresh(%Client{} = client, oauth_data, opts \\ []) do
    HTTP.post(client, "/oauth/token", oauth_data, opts)
  end
end
