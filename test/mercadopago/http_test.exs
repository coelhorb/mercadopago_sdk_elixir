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

  describe "patch/4" do
    test "sends a JSON body with the PATCH method" do
      Req.Test.stub(:http_patch, fn conn ->
        assert conn.method == "PATCH"
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(body) == %{"operating_mode" => "PDV"}

        Req.Test.json(conn, %{"ok" => true})
      end)

      client = new(:http_patch)

      assert {:ok, %{status: 200, response: %{"ok" => true}}} =
               Mercadopago.HTTP.patch(client, "/v1/anything", %{operating_mode: "PDV"})
    end

    test "carries the standard auth and tracking headers" do
      Req.Test.stub(:http_patch_headers, fn conn ->
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test_token"]
        assert [_key] = Plug.Conn.get_req_header(conn, "x-idempotency-key")

        Req.Test.json(conn, %{"ok" => true})
      end)

      client = new(:http_patch_headers)

      assert {:ok, %{status: 200}} = Mercadopago.HTTP.patch(client, "/v1/anything", %{a: 1})
    end
  end

  describe "multipart bodies" do
    test "posts multipart/form-data when the body is {:multipart, parts}" do
      Req.Test.stub(:http_multipart, fn conn ->
        assert ["multipart/form-data; boundary=" <> _] =
                 Plug.Conn.get_req_header(conn, "content-type")

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert body =~ "name=\"kind\""
        assert body =~ "invoice"
        assert body =~ "filename=\"proof.pdf\""
        assert body =~ "%PDF-1.4 stub"

        Req.Test.json(conn, %{"id" => "doc_1"})
      end)

      client = new(:http_multipart)

      parts = [
        {:kind, "invoice"},
        {:file, {"%PDF-1.4 stub", filename: "proof.pdf", content_type: "application/pdf"}}
      ]

      assert {:ok, %{status: 200, response: %{"id" => "doc_1"}}} =
               Mercadopago.HTTP.post(client, "/v1/anything", {:multipart, parts})
    end

    test "a plain map body is still sent as JSON" do
      Req.Test.stub(:http_json_unchanged, fn conn ->
        assert ["application/json" <> _] = Plug.Conn.get_req_header(conn, "content-type")

        Req.Test.json(conn, %{"ok" => true})
      end)

      client = new(:http_json_unchanged)

      assert {:ok, %{status: 200}} = Mercadopago.HTTP.post(client, "/v1/anything", %{a: 1})
    end
  end

  describe "unwrap/1" do
    test "unwraps a success to its body" do
      assert {:ok, %{"id" => "pay_1"}} =
               Mercadopago.HTTP.unwrap({:ok, %{status: 200, response: %{"id" => "pay_1"}}})
    end

    test "turns a 4xx into a Mercadopago.Error carrying status, body and cause" do
      body = %{
        "message" => "invalid_card_number",
        "cause" => [%{"code" => "3034"}]
      }

      assert {:error, error} = Mercadopago.HTTP.unwrap({:ok, %{status: 400, response: body}})

      assert %Mercadopago.Error{status: 400, response: ^body, cause: [%{"code" => "3034"}]} =
               error

      assert Exception.message(error) == "invalid_card_number (HTTP 400)"
    end

    test "falls back to a generic message when the body names no error" do
      assert {:error, %Mercadopago.Error{message: message}} =
               Mercadopago.HTTP.unwrap({:ok, %{status: 500, response: nil}})

      assert message == "MercadoPago API error (HTTP 500)"
    end

    test "passes a transport failure through unchanged" do
      assert {:error, :timeout} = Mercadopago.HTTP.unwrap({:error, :timeout})
    end

    test "composes with a real resource call" do
      Req.Test.stub(:http_unwrap_live, fn conn ->
        conn
        |> Plug.Conn.put_status(404)
        |> Req.Test.json(%{"message" => "Payment not found"})
      end)

      client = new(:http_unwrap_live)

      assert {:error, %Mercadopago.Error{status: 404}} =
               client |> Mercadopago.Payment.get("missing") |> Mercadopago.HTTP.unwrap()
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

  describe "retry_on" do
    test "retries a status that is only retryable because retry_on says so" do
      parent = self()

      Req.Test.stub(:http_retry_on_custom, fn conn ->
        send(parent, :request)

        conn
        |> Plug.Conn.put_status(418)
        |> Req.Test.json(%{"error" => "teapot"})
      end)

      client = new(:http_retry_on_custom)

      assert {:ok, %{status: 418}} =
               Mercadopago.HTTP.get(client, "/v1/anything", nil,
                 retry_on: [418],
                 max_retries: 2,
                 retry_delay: 0
               )

      assert_received :request
      assert_received :request
      refute_received :request
    end

    test "a narrowed retry_on stops a default status from being retried" do
      parent = self()

      Req.Test.stub(:http_retry_on_narrowed, fn conn ->
        send(parent, :request)

        conn
        |> Plug.Conn.put_status(503)
        |> Req.Test.json(%{"error" => "unavailable"})
      end)

      client = new(:http_retry_on_narrowed)

      assert {:ok, %{status: 503}} =
               Mercadopago.HTTP.get(client, "/v1/anything", nil,
                 retry_on: [429],
                 max_retries: 3,
                 retry_delay: 0
               )

      assert_received :request
      refute_received :request
    end

    test "the client-level retry_on applies without a per-call override" do
      parent = self()

      Req.Test.stub(:http_retry_on_client, fn conn ->
        send(parent, :request)

        conn
        |> Plug.Conn.put_status(503)
        |> Req.Test.json(%{"error" => "unavailable"})
      end)

      client = new(:http_retry_on_client, retry_on: [429], retry_delay: 0)

      assert {:ok, %{status: 503}} = Mercadopago.HTTP.get(client, "/v1/anything")

      assert_received :request
      refute_received :request
    end

    test "a transport failure is retried whatever retry_on says" do
      counter = :counters.new(1, [])

      Req.Test.stub(:http_retry_on_transport, fn conn ->
        case :counters.get(counter, 1) do
          0 ->
            :counters.add(counter, 1, 1)
            Req.Test.transport_error(conn, :closed)

          _settled ->
            Req.Test.json(conn, %{"ok" => true})
        end
      end)

      client = new(:http_retry_on_transport)

      assert {:ok, %{status: 200, response: %{"ok" => true}}} =
               Mercadopago.HTTP.get(client, "/v1/anything", nil,
                 retry_on: [],
                 max_retries: 2,
                 retry_delay: 0
               )
    end
  end

  describe "response diagnostics" do
    test "lifts x-request-id and Retry-After out of the headers" do
      Req.Test.stub(:http_diagnostics, fn conn ->
        conn
        |> Plug.Conn.put_resp_header("x-request-id", "req-9f2c")
        |> Plug.Conn.put_resp_header("retry-after", "30")
        |> Plug.Conn.put_status(429)
        |> Req.Test.json(%{"message" => "Too many requests"})
      end)

      client = new(:http_diagnostics)

      assert {:ok, %{status: 429, request_id: "req-9f2c", retry_after: 30}} =
               Mercadopago.HTTP.get(client, "/v1/anything", nil, max_retries: 1)
    end

    test "both are nil when the server sends neither header" do
      Req.Test.stub(:http_no_diagnostics, fn conn ->
        Req.Test.json(conn, %{"id" => 1})
      end)

      assert {:ok, %{status: 200, request_id: nil, retry_after: nil}} =
               Mercadopago.HTTP.get(new(:http_no_diagnostics), "/v1/anything")
    end

    test "an HTTP-date Retry-After is reported as absent, not as a bogus number" do
      Req.Test.stub(:http_http_date_retry_after, fn conn ->
        conn
        |> Plug.Conn.put_resp_header("retry-after", "Wed, 21 Oct 2026 07:28:00 GMT")
        |> Plug.Conn.put_status(503)
        |> Req.Test.json(%{"error" => "unavailable"})
      end)

      client = new(:http_http_date_retry_after)

      assert {:ok, %{status: 503, retry_after: nil}} =
               Mercadopago.HTTP.get(client, "/v1/anything", nil, max_retries: 1)
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

    test "announces each retry with its delay and the status that caused it" do
      ref = :telemetry_test.attach_event_handlers(self(), [[:mercadopago, :request, :retry]])
      on_exit(fn -> :telemetry.detach(ref) end)

      Req.Test.stub(:http_retry_event, fn conn ->
        conn
        |> Plug.Conn.put_status(502)
        |> Req.Test.json(%{"error" => "bad gateway"})
      end)

      client = new(:http_retry_event)

      assert {:ok, %{status: 502}} =
               Mercadopago.HTTP.get(client, "/v1/retry-probe", nil,
                 max_retries: 3,
                 retry_delay: 0
               )

      path = "/v1/retry-probe"

      assert_receive {[:mercadopago, :request, :retry], ^ref, %{delay: delay},
                      %{method: :get, path: ^path, attempt: 0, status: 502}}

      assert is_integer(delay) and delay >= 0

      assert_receive {[:mercadopago, :request, :retry], ^ref, %{delay: _},
                      %{path: ^path, attempt: 1, status: 502}}

      # Three attempts means two retries — the last failure is returned, not retried.
      refute_receive {[:mercadopago, :request, :retry], ^ref, _measurements, _metadata}
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
