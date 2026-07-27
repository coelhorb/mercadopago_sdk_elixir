defmodule Mercadopago.OAuth do
  @moduledoc """
  OAuth 2.0 authorization code flow for marketplace/platform integrations.

  The token endpoint needs no prior credentials, so bootstrap it with a tokenless
  client — `Mercadopago.new(nil)` — and keep the app secret in the request body:

      verifier = Mercadopago.OAuth.generate_code_verifier()

      url =
        Mercadopago.OAuth.get_authorization_url(app_id, redirect_uri, state,
          code_challenge: Mercadopago.OAuth.code_challenge(verifier)
        )

      # ...redirect the seller to `url`, then on the callback:

      {:ok, %{status: 200, response: %{"access_token" => token}}} =
        Mercadopago.OAuth.create(Mercadopago.new(nil), %{
          client_id: app_id,
          client_secret: app_secret,
          code: code,
          redirect_uri: redirect_uri,
          code_verifier: verifier
        })

  Store `verifier` in the user's session alongside `state`; both must survive the
  redirect. PKCE is optional on MercadoPago today, but it removes the value of an
  intercepted authorization code and costs nothing to include.
  """

  alias Mercadopago.{Client, Config, HTTP}

  @doc """
  Builds the authorization URL to redirect the seller to. Does not make an HTTP call.

  `random_id` is the CSRF `state`: generate it per authorization attempt, store it
  in the session, and compare it on the callback. The SDK neither generates nor
  verifies it.

  ## Options

    * `:code_challenge` - PKCE challenge from `code_challenge/1`; omitted when nil
    * `:code_challenge_method` - defaults to `"S256"` when a challenge is given
  """
  @spec get_authorization_url(String.t(), String.t(), String.t(), keyword()) :: String.t()
  def get_authorization_url(app_id, redirect_uri, random_id, opts \\ []) do
    params =
      %{
        client_id: app_id,
        response_type: "code",
        platform_id: "mp",
        state: random_id,
        redirect_uri: redirect_uri
      }
      |> put_pkce(opts[:code_challenge], opts[:code_challenge_method] || "S256")
      |> URI.encode_query()

    "#{Config.auth_base_url()}?#{params}"
  end

  @doc """
  Generates a PKCE code verifier: 32 random bytes, base64url-encoded without
  padding (RFC 7636 section 4.1). Keep it server-side; only its challenge is public.
  """
  @spec generate_code_verifier() :: String.t()
  def generate_code_verifier do
    32 |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)
  end

  @doc """
  Derives the S256 PKCE challenge from a verifier (RFC 7636 section 4.2).
  """
  @spec code_challenge(String.t()) :: String.t()
  def code_challenge(code_verifier) when is_binary(code_verifier) do
    :sha256 |> :crypto.hash(code_verifier) |> Base.url_encode64(padding: false)
  end

  @doc """
  Exchanges an authorization code for an access token.

  `grant_type` defaults to `"authorization_code"`. Include `:code_verifier` when
  the authorization URL carried a PKCE challenge.
  """
  @spec create(Client.t(), map(), keyword()) :: HTTP.response()
  def create(%Client{} = client, oauth_data, opts \\ []) do
    HTTP.post(client, "/oauth/token", put_grant_type(oauth_data, "authorization_code"), opts)
  end

  @doc """
  Refreshes an expired access token. `grant_type` defaults to `"refresh_token"`.
  """
  @spec refresh(Client.t(), map(), keyword()) :: HTTP.response()
  def refresh(%Client{} = client, oauth_data, opts \\ []) do
    HTTP.post(client, "/oauth/token", put_grant_type(oauth_data, "refresh_token"), opts)
  end

  defp put_pkce(params, nil, _method), do: params

  defp put_pkce(params, challenge, method) do
    Map.merge(params, %{code_challenge: challenge, code_challenge_method: method})
  end

  # Respects an explicit grant_type under either key style rather than overwriting
  # it, so a caller driving an unusual grant is not silently corrected.
  defp put_grant_type(oauth_data, default) do
    if Map.has_key?(oauth_data, :grant_type) or Map.has_key?(oauth_data, "grant_type") do
      oauth_data
    else
      Map.put(oauth_data, grant_type_key(oauth_data), default)
    end
  end

  defp grant_type_key(oauth_data) do
    if Enum.any?(Map.keys(oauth_data), &is_binary/1), do: "grant_type", else: :grant_type
  end
end
