defmodule Mercadopago.PaymentTest do
  use ExUnit.Case, async: true

  import Mercadopago.Test.StubClient, only: [new: 1]

  describe "create/3" do
    test "returns {:ok, %{status: 201, response: payment}} on success" do
      Req.Test.stub(:payment_create, fn conn ->
        conn
        |> Plug.Conn.put_status(201)
        |> Req.Test.json(%{"id" => "pay_123", "status" => "approved"})
      end)

      client = new(:payment_create)

      assert {:ok, %{status: 201, response: %{"id" => "pay_123", "status" => "approved"}}} =
               Mercadopago.Payment.create(client, %{transaction_amount: 100})
    end

    test "returns {:ok, %{status: 400, response: error}} on bad request" do
      Req.Test.stub(:payment_create_error, fn conn ->
        conn
        |> Plug.Conn.put_status(400)
        |> Req.Test.json(%{"error" => "bad_request", "message" => "Invalid params"})
      end)

      client = new(:payment_create_error)

      assert {:ok, %{status: 400, response: %{"error" => "bad_request"}}} =
               Mercadopago.Payment.create(client, %{})
    end
  end

  describe "get/3" do
    test "returns payment by id" do
      Req.Test.stub(:payment_get, fn conn ->
        Req.Test.json(conn, %{"id" => "pay_456", "status" => "approved"})
      end)

      client = new(:payment_get)

      assert {:ok, %{status: 200, response: %{"id" => "pay_456"}}} =
               Mercadopago.Payment.get(client, "pay_456")
    end
  end

  describe "search/3" do
    test "returns search results" do
      Req.Test.stub(:payment_search, fn conn ->
        Req.Test.json(conn, %{"results" => [%{"id" => "pay_1"}], "paging" => %{"total" => 1}})
      end)

      client = new(:payment_search)

      assert {:ok, %{status: 200, response: %{"results" => [%{"id" => "pay_1"}]}}} =
               Mercadopago.Payment.search(client, %{status: "approved"})
    end
  end

  describe "update/4" do
    test "sends PUT and returns updated payment" do
      Req.Test.stub(:payment_update, fn conn ->
        assert conn.method == "PUT"
        Req.Test.json(conn, %{"id" => "pay_789", "status" => "cancelled"})
      end)

      client = new(:payment_update)

      assert {:ok, %{status: 200, response: %{"id" => "pay_789", "status" => "cancelled"}}} =
               Mercadopago.Payment.update(client, "pay_789", %{status: "cancelled"})
    end
  end
end
