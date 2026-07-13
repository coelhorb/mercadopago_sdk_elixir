defmodule Mercadopago.OrderTest do
  use ExUnit.Case, async: true

  import Mercadopago.Test.StubClient, only: [new: 1]

  defp decoded_body(conn) do
    {:ok, body, conn} = Plug.Conn.read_body(conn)
    {Jason.decode!(body), conn}
  end

  describe "create_checkout_pro/3" do
    test "injects type and processing_mode defaults when omitted" do
      Req.Test.stub(:order_cho_pro_defaults, fn conn ->
        {body, conn} = decoded_body(conn)
        assert body["type"] == "online"
        assert body["processing_mode"] == "manual"
        assert body["total_amount"] == "100.00"

        conn
        |> Plug.Conn.put_status(201)
        |> Req.Test.json(%{"id" => "ord_123", "status" => "created"})
      end)

      client = new(:order_cho_pro_defaults)

      assert {:ok, %{status: 201, response: %{"id" => "ord_123"}}} =
               Mercadopago.Order.create_checkout_pro(client, %{total_amount: "100.00"})
    end

    test "keeps matching values provided with atom keys" do
      Req.Test.stub(:order_cho_pro_atom, fn conn ->
        {body, conn} = decoded_body(conn)
        assert body["type"] == "online"
        assert body["processing_mode"] == "manual"

        conn
        |> Plug.Conn.put_status(201)
        |> Req.Test.json(%{"id" => "ord_124"})
      end)

      client = new(:order_cho_pro_atom)

      order_data = %{type: "online", processing_mode: "manual", total_amount: "50.00"}

      assert {:ok, %{status: 201, response: %{"id" => "ord_124"}}} =
               Mercadopago.Order.create_checkout_pro(client, order_data)
    end

    test "keeps matching values provided with string keys" do
      Req.Test.stub(:order_cho_pro_string, fn conn ->
        {body, conn} = decoded_body(conn)
        assert body["type"] == "online"
        assert body["processing_mode"] == "manual"

        conn
        |> Plug.Conn.put_status(201)
        |> Req.Test.json(%{"id" => "ord_125"})
      end)

      client = new(:order_cho_pro_string)

      order_data = %{"type" => "online", "processing_mode" => "manual"}

      assert {:ok, %{status: 201, response: %{"id" => "ord_125"}}} =
               Mercadopago.Order.create_checkout_pro(client, order_data)
    end

    test "raises ArgumentError when type is incompatible" do
      client = new(:order_cho_pro_bad_type)

      assert_raise ArgumentError, "Param type must be online", fn ->
        Mercadopago.Order.create_checkout_pro(client, %{type: "offline"})
      end
    end

    test "raises ArgumentError when processing_mode is incompatible (string key)" do
      client = new(:order_cho_pro_bad_mode)

      assert_raise ArgumentError, "Param processing_mode must be manual", fn ->
        Mercadopago.Order.create_checkout_pro(client, %{"processing_mode" => "automatic"})
      end
    end
  end

  describe "create/3" do
    test "does not inject Checkout Pro defaults" do
      Req.Test.stub(:order_create_plain, fn conn ->
        {body, conn} = decoded_body(conn)
        refute Map.has_key?(body, "type")
        refute Map.has_key?(body, "processing_mode")

        conn
        |> Plug.Conn.put_status(201)
        |> Req.Test.json(%{"id" => "ord_126"})
      end)

      client = new(:order_create_plain)

      assert {:ok, %{status: 201, response: %{"id" => "ord_126"}}} =
               Mercadopago.Order.create(client, %{total_amount: "10.00"})
    end
  end

  describe "search/3" do
    test "sends filters as query-string parameters" do
      Req.Test.stub(:order_search, fn conn ->
        assert conn.query_string == "status=created"
        Req.Test.json(conn, %{"results" => [%{"id" => "ord_1"}]})
      end)

      client = new(:order_search)

      assert {:ok, %{status: 200, response: %{"results" => [%{"id" => "ord_1"}]}}} =
               Mercadopago.Order.search(client, %{status: "created"})
    end
  end
end
