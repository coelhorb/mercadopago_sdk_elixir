defmodule Mercadopago.HTTPTest do
  use ExUnit.Case, async: true

  import Mercadopago.Test.StubClient, only: [new: 1, new: 2]

  describe "custom headers" do
    test "client custom_headers override generated headers case-insensitively" do
      Req.Test.stub(:http_client_headers, fn conn ->
        assert Plug.Conn.get_req_header(conn, "x-idempotency-key") == ["fixed-key-1"]
        Req.Test.json(conn, %{"ok" => true})
      end)

      client =
        new(:http_client_headers, custom_headers: %{"X-Idempotency-Key" => "fixed-key-1"})

      assert {:ok, %{status: 200}} = Mercadopago.HTTP.get(client, "/v1/anything")
    end

    test "per-call custom_headers win over the client's" do
      Req.Test.stub(:http_per_call_headers, fn conn ->
        assert Plug.Conn.get_req_header(conn, "x-idempotency-key") == ["per-call-key"]
        Req.Test.json(conn, %{"ok" => true})
      end)

      client =
        new(:http_per_call_headers, custom_headers: %{"x-idempotency-key" => "client-key"})

      assert {:ok, %{status: 200}} =
               Mercadopago.HTTP.post(client, "/v1/anything", %{},
                 custom_headers: %{"X-IDEMPOTENCY-KEY" => "per-call-key"}
               )
    end
  end

  describe "per-call overrides" do
    test "access_token overrides the client token for one request" do
      Req.Test.stub(:http_token_override, fn conn ->
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer other_token"]
        Req.Test.json(conn, %{"ok" => true})
      end)

      client = new(:http_token_override)

      assert {:ok, %{status: 200}} =
               Mercadopago.HTTP.get(client, "/v1/anything", nil, access_token: "other_token")
    end

    test "max_retries: 1 makes GET give up after a single attempt" do
      parent = self()

      Req.Test.stub(:http_retry_budget, fn conn ->
        send(parent, :request)

        conn
        |> Plug.Conn.put_status(500)
        |> Req.Test.json(%{"error" => "boom"})
      end)

      client = new(:http_retry_budget)

      assert {:ok, %{status: 500}} =
               Mercadopago.HTTP.get(client, "/v1/anything", nil, max_retries: 1)

      assert_received :request
      refute_received :request
    end
  end
end
