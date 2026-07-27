defmodule Mercadopago.OAuthTest do
  use ExUnit.Case, async: true

  import Mercadopago.Test.StubClient, only: [new: 1]

  alias Mercadopago.OAuth

  defp query(url), do: url |> URI.parse() |> Map.fetch!(:query) |> URI.decode_query()

  defp decoded_body(conn) do
    {:ok, body, conn} = Plug.Conn.read_body(conn)
    {Jason.decode!(body), conn}
  end

  describe "get_authorization_url/4" do
    test "builds the base params without PKCE" do
      url = OAuth.get_authorization_url("app-1", "https://shop.test/cb", "state-1")

      assert %{
               "client_id" => "app-1",
               "response_type" => "code",
               "platform_id" => "mp",
               "state" => "state-1",
               "redirect_uri" => "https://shop.test/cb"
             } = query(url)
    end

    test "omits PKCE params when no challenge is given" do
      params = query(OAuth.get_authorization_url("app-1", "https://shop.test/cb", "s"))

      refute Map.has_key?(params, "code_challenge")
      refute Map.has_key?(params, "code_challenge_method")
    end

    test "includes the challenge and defaults the method to S256" do
      url =
        OAuth.get_authorization_url("app-1", "https://shop.test/cb", "s",
          code_challenge: "abc123"
        )

      assert %{"code_challenge" => "abc123", "code_challenge_method" => "S256"} = query(url)
    end

    test "honours an explicit challenge method" do
      url =
        OAuth.get_authorization_url("app-1", "https://shop.test/cb", "s",
          code_challenge: "abc123",
          code_challenge_method: "plain"
        )

      assert %{"code_challenge_method" => "plain"} = query(url)
    end
  end

  describe "PKCE helpers" do
    test "generate_code_verifier/0 is URL-safe, unpadded and unique per call" do
      verifier = OAuth.generate_code_verifier()

      assert verifier =~ ~r/\A[A-Za-z0-9\-_]+\z/
      assert String.length(verifier) in 43..128
      refute verifier == OAuth.generate_code_verifier()
    end

    test "code_challenge/1 matches the RFC 7636 S256 derivation" do
      verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
      expected = :sha256 |> :crypto.hash(verifier) |> Base.url_encode64(padding: false)

      assert OAuth.code_challenge(verifier) == expected
      assert OAuth.code_challenge(verifier) =~ ~r/\A[A-Za-z0-9\-_]+\z/
    end
  end

  describe "token requests" do
    test "create/3 defaults grant_type to authorization_code" do
      Req.Test.stub(:oauth_create, fn conn ->
        {body, conn} = decoded_body(conn)
        assert body["grant_type"] == "authorization_code"
        assert body["code_verifier"] == "verifier-1"

        Req.Test.json(conn, %{"access_token" => "APP_USR-1"})
      end)

      assert {:ok, %{status: 200, response: %{"access_token" => "APP_USR-1"}}} =
               OAuth.create(new(:oauth_create), %{code: "c", code_verifier: "verifier-1"})
    end

    test "refresh/3 defaults grant_type to refresh_token" do
      Req.Test.stub(:oauth_refresh, fn conn ->
        {body, conn} = decoded_body(conn)
        assert body["grant_type"] == "refresh_token"

        Req.Test.json(conn, %{"access_token" => "APP_USR-2"})
      end)

      assert {:ok, %{status: 200}} =
               OAuth.refresh(new(:oauth_refresh), %{refresh_token: "r"})
    end

    test "an explicit grant_type is not overwritten" do
      Req.Test.stub(:oauth_explicit_grant, fn conn ->
        {body, conn} = decoded_body(conn)
        assert body["grant_type"] == "client_credentials"

        Req.Test.json(conn, %{"access_token" => "APP_USR-3"})
      end)

      assert {:ok, %{status: 200}} =
               OAuth.create(new(:oauth_explicit_grant), %{"grant_type" => "client_credentials"})
    end
  end

  describe "tokenless bootstrap" do
    test "a nil-token client sends no Authorization header" do
      Req.Test.stub(:oauth_no_token, fn conn ->
        assert Plug.Conn.get_req_header(conn, "authorization") == []

        Req.Test.json(conn, %{"access_token" => "APP_USR-4"})
      end)

      client = Mercadopago.new(nil, plug: {Req.Test, :oauth_no_token})

      assert {:ok, %{status: 200}} = OAuth.create(client, %{code: "c"})
    end

    test "an empty-string token also omits the header rather than sending 'Bearer '" do
      Req.Test.stub(:oauth_blank_token, fn conn ->
        assert Plug.Conn.get_req_header(conn, "authorization") == []

        Req.Test.json(conn, %{"access_token" => "APP_USR-5"})
      end)

      client = Mercadopago.new("", plug: {Req.Test, :oauth_blank_token})

      assert {:ok, %{status: 200}} = OAuth.create(client, %{code: "c"})
    end

    test "a normal client still sends Bearer" do
      Req.Test.stub(:oauth_with_token, fn conn ->
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test_token"]

        Req.Test.json(conn, %{"ok" => true})
      end)

      assert {:ok, %{status: 200}} = OAuth.create(new(:oauth_with_token), %{code: "c"})
    end
  end
end
