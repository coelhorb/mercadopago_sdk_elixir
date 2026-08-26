defmodule Mercadopago.ErrorTest do
  use ExUnit.Case, async: true

  import Mercadopago.Test.StubClient, only: [new: 1]

  alias Mercadopago.{Error, HTTP}

  describe "kind_for/1" do
    test "maps each documented status to its class" do
      for {status, kind} <- [
            {400, :bad_request},
            {401, :authentication},
            {402, :payment},
            {403, :forbidden},
            {404, :not_found},
            {409, :idempotency},
            {422, :validation},
            {423, :resource_locked},
            {424, :dependency},
            {429, :rate_limit}
          ] do
        assert Error.kind_for(status) == kind
      end
    end

    test "any 5xx is a server error" do
      for status <- [500, 502, 503, 504, 599] do
        assert Error.kind_for(status) == :server
      end
    end

    test "anything else falls back to :api" do
      for status <- [418, 451, 200] do
        assert Error.kind_for(status) == :api
      end
    end
  end

  describe "new/3" do
    test "carries the kind, the untouched body and the cause list" do
      body = %{"message" => "Invalid card", "cause" => [%{"code" => "3034"}]}

      assert %Error{
               status: 400,
               kind: :bad_request,
               response: ^body,
               cause: [%{"code" => "3034"}],
               message: "Invalid card (HTTP 400)"
             } = Error.new(400, body)
    end

    test "request_id and retry_after default to nil" do
      assert %Error{request_id: nil, retry_after: nil} = Error.new(404, %{})
    end
  end

  describe "unwrap/1" do
    test "fills request_id and retry_after from the response headers" do
      Req.Test.stub(:error_rate_limited, fn conn ->
        conn
        |> Plug.Conn.put_resp_header("x-request-id", "req-abc-123")
        |> Plug.Conn.put_resp_header("retry-after", "12")
        |> Plug.Conn.put_status(429)
        |> Req.Test.json(%{"message" => "Too many requests"})
      end)

      client = new(:error_rate_limited)

      assert {:error,
              %Error{
                kind: :rate_limit,
                status: 429,
                request_id: "req-abc-123",
                retry_after: 12
              }} =
               client
               |> Mercadopago.Payment.get("pay_1", max_retries: 1)
               |> HTTP.unwrap()
    end

    test "a 404 unwraps to kind: :not_found" do
      Req.Test.stub(:error_not_found, fn conn ->
        conn
        |> Plug.Conn.put_status(404)
        |> Req.Test.json(%{"message" => "Payment not found"})
      end)

      assert {:error, %Error{kind: :not_found, request_id: nil}} =
               new(:error_not_found) |> Mercadopago.Payment.get("nope") |> HTTP.unwrap()
    end

    test "a success still unwraps to the bare body" do
      Req.Test.stub(:error_success, fn conn -> Req.Test.json(conn, %{"id" => "pay_1"}) end)

      assert {:ok, %{"id" => "pay_1"}} =
               new(:error_success) |> Mercadopago.Payment.get("pay_1") |> HTTP.unwrap()
    end
  end
end
