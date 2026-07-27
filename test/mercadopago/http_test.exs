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

  # `retry_delay: 0` keeps the backoff at the 1ms jitter floor so the suite
  # never actually waits.
  describe "GET retry policy" do
    test "retries a retryable status until the attempt budget runs out" do
      parent = self()

      Req.Test.stub(:http_retry_exhausted, fn conn ->
        send(parent, :request)

        conn
        |> Plug.Conn.put_status(503)
        |> Req.Test.json(%{"error" => "unavailable"})
      end)

      client = new(:http_retry_exhausted)

      assert {:ok, %{status: 503}} =
               Mercadopago.HTTP.get(client, "/v1/anything", nil,
                 max_retries: 3,
                 retry_delay: 0
               )

      assert_received :request
      assert_received :request
      assert_received :request
      refute_received :request
    end

    test "retries a closed connection and returns the eventual success" do
      counter = :counters.new(1, [])

      Req.Test.stub(:http_retry_closed, fn conn ->
        case :counters.get(counter, 1) do
          0 ->
            :counters.add(counter, 1, 1)
            Req.Test.transport_error(conn, :closed)

          _retried ->
            Req.Test.json(conn, %{"ok" => true})
        end
      end)

      client = new(:http_retry_closed)

      assert {:ok, %{status: 200, response: %{"ok" => true}}} =
               Mercadopago.HTTP.get(client, "/v1/anything", nil, retry_delay: 0)
    end

    test "does not retry a timeout, whose latency budget is already spent" do
      parent = self()

      Req.Test.stub(:http_no_retry_timeout, fn conn ->
        send(parent, :request)
        Req.Test.transport_error(conn, :timeout)
      end)

      client = new(:http_no_retry_timeout)

      assert {:error, %Req.TransportError{reason: :timeout}} =
               Mercadopago.HTTP.get(client, "/v1/anything", nil, retry_delay: 0)

      assert_received :request
      refute_received :request
    end

    test "caps a hostile Retry-After at max_retry_delay" do
      Req.Test.stub(:http_retry_after_cap, fn conn ->
        conn
        |> Plug.Conn.put_resp_header("retry-after", "3600")
        |> Plug.Conn.put_status(429)
        |> Req.Test.json(%{"error" => "too many requests"})
      end)

      client = new(:http_retry_after_cap)

      {elapsed_us, result} =
        :timer.tc(fn ->
          Mercadopago.HTTP.get(client, "/v1/anything", nil,
            max_retries: 2,
            max_retry_delay: 0
          )
        end)

      assert {:ok, %{status: 429}} = result
      assert elapsed_us < 1_000_000
    end

    test "reuses the same idempotency key across retries" do
      parent = self()

      Req.Test.stub(:http_retry_idempotency, fn conn ->
        send(parent, {:key, Plug.Conn.get_req_header(conn, "x-idempotency-key")})

        conn
        |> Plug.Conn.put_status(500)
        |> Req.Test.json(%{"error" => "boom"})
      end)

      client = new(:http_retry_idempotency)

      assert {:ok, %{status: 500}} =
               Mercadopago.HTTP.get(client, "/v1/anything", nil,
                 max_retries: 2,
                 retry_delay: 0
               )

      assert_received {:key, [key]}
      assert_received {:key, [^key]}
    end
  end

  describe "telemetry" do
    test "emits one span per attempt, without leaking the access token" do
      ref =
        :telemetry_test.attach_event_handlers(self(), [
          [:mercadopago, :request, :start],
          [:mercadopago, :request, :stop]
        ])

      on_exit(fn -> :telemetry.detach(ref) end)

      Req.Test.stub(:http_telemetry, fn conn ->
        conn
        |> Plug.Conn.put_status(500)
        |> Req.Test.json(%{"error" => "boom"})
      end)

      client = new(:http_telemetry)

      assert {:ok, %{status: 500}} =
               Mercadopago.HTTP.get(client, "/v1/telemetry-probe", nil,
                 max_retries: 2,
                 retry_delay: 0
               )

      path = "/v1/telemetry-probe"

      assert_receive {[:mercadopago, :request, :start], ^ref, %{system_time: _},
                      %{method: :get, path: ^path, attempt: 0}}

      assert_receive {[:mercadopago, :request, :stop], ^ref, %{duration: _},
                      %{path: ^path, attempt: 0, status: 500} = metadata}

      assert_receive {[:mercadopago, :request, :stop], ^ref, %{duration: _},
                      %{path: ^path, attempt: 1, status: 500}}

      refute metadata |> inspect() |> String.contains?("test_token")
    end

    test "reports a transport failure as an error in the stop metadata" do
      ref = :telemetry_test.attach_event_handlers(self(), [[:mercadopago, :request, :stop]])
      on_exit(fn -> :telemetry.detach(ref) end)

      Req.Test.stub(:http_telemetry_error, fn conn ->
        Req.Test.transport_error(conn, :timeout)
      end)

      client = new(:http_telemetry_error)

      assert {:error, _reason} =
               Mercadopago.HTTP.get(client, "/v1/telemetry-error-probe", nil, retry_delay: 0)

      path = "/v1/telemetry-error-probe"

      assert_receive {[:mercadopago, :request, :stop], ^ref, %{duration: _},
                      %{path: ^path, error: %Req.TransportError{reason: :timeout}}}
    end
  end
end
