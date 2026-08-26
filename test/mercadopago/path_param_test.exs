defmodule Mercadopago.PathParamTest do
  use ExUnit.Case, async: true

  import Mercadopago.Test.StubClient, only: [new: 1]

  @unsafe_id "../../applications/123"
  @encoded_id "..%2F..%2Fapplications%2F123"

  describe "encode_path_param/1" do
    test "escapes path traversal like the Ruby SDK" do
      assert Mercadopago.HTTP.encode_path_param(@unsafe_id) == @encoded_id
    end

    test "percent-encodes reserved characters, spaces, and Unicode" do
      assert Mercadopago.HTTP.encode_path_param("a b+c/%?x#á") ==
               "a%20b%2Bc%2F%25%3Fx%23%C3%A1"
    end

    test "keeps unreserved characters and accepts numeric ids" do
      assert Mercadopago.HTTP.encode_path_param("abc-123_~.x") == "abc-123_~.x"
      assert Mercadopago.HTTP.encode_path_param(123_456) == "123456"
    end

    test "rejects blank ids that would silently build the collection path" do
      for blank <- [nil, "", :undefined] do
        assert_raise ArgumentError, fn -> Mercadopago.HTTP.encode_path_param(blank) end
      end
    end
  end

  test "a nil id fails loudly instead of hitting the collection endpoint" do
    client = new(:nil_id_guard)

    assert_raise ArgumentError, fn -> Mercadopago.Payment.get(client, nil) end
  end

  test "every dynamic resource path encodes each id segment" do
    test_pid = self()

    Req.Test.stub(:encoded_resource_paths, fn conn ->
      send(test_pid, {:request, conn.method, conn.request_path})
      Req.Test.json(conn, %{})
    end)

    client = new(:encoded_resource_paths)

    for {method, path, module, function, args} <- resource_calls() do
      assert {:ok, %{status: 200}} = apply(module, function, [client | args])
      assert_receive {:request, ^method, ^path}
    end
  end

  defp resource_calls do
    id = @unsafe_id
    encoded = @encoded_id
    data = %{}

    [
      {"GET", "/v1/advanced_payments/#{encoded}", Mercadopago.AdvancedPayment, :get, [id]},
      {"PUT", "/v1/advanced_payments/#{encoded}", Mercadopago.AdvancedPayment, :capture, [id]},
      {"PUT", "/v1/advanced_payments/#{encoded}", Mercadopago.AdvancedPayment, :update,
       [id, data]},
      {"PUT", "/v1/advanced_payments/#{encoded}", Mercadopago.AdvancedPayment, :cancel, [id]},
      {"POST", "/v1/advanced_payments/#{encoded}/disburses", Mercadopago.AdvancedPayment,
       :update_release_date, [id, "2026-07-27 12:00:00.000000"]},
      {"GET", "/v1/customers/#{encoded}/cards/#{encoded}", Mercadopago.Card, :get, [id, id]},
      {"POST", "/v1/customers/#{encoded}/cards/", Mercadopago.Card, :create, [id, data]},
      {"PUT", "/v1/customers/#{encoded}/cards/#{encoded}", Mercadopago.Card, :update,
       [id, id, data]},
      {"DELETE", "/v1/customers/#{encoded}/cards/#{encoded}", Mercadopago.Card, :delete,
       [id, id]},
      {"GET", "/v1/customers/#{encoded}/cards", Mercadopago.Card, :list, [id]},
      {"GET", "/v1/card_tokens/#{encoded}", Mercadopago.CardToken, :get, [id]},
      {"GET", "/v1/chargebacks/#{encoded}", Mercadopago.Chargeback, :get, [id]},
      {"GET", "/v1/customers/#{encoded}", Mercadopago.Customer, :get, [id]},
      {"PUT", "/v1/customers/#{encoded}", Mercadopago.Customer, :update, [id, data]},
      {"DELETE", "/v1/customers/#{encoded}", Mercadopago.Customer, :delete, [id]},
      {"GET", "/v1/advanced_payments/#{encoded}/refunds", Mercadopago.DisbursementRefund, :list,
       [id]},
      {"POST", "/v1/advanced_payments/#{encoded}/refunds", Mercadopago.DisbursementRefund,
       :create_all, [id]},
      {"POST", "/v1/advanced_payments/#{encoded}/disbursements/#{encoded}/refunds",
       Mercadopago.DisbursementRefund, :create, [id, id]},
      {"GET", "/authorized_payments/#{encoded}", Mercadopago.Invoice, :get, [id]},
      {"GET", "/merchant_orders/#{encoded}", Mercadopago.MerchantOrder, :get, [id]},
      {"PUT", "/merchant_orders/#{encoded}", Mercadopago.MerchantOrder, :update, [id, data]},
      {"GET", "/v1/orders/#{encoded}", Mercadopago.Order, :get, [id]},
      {"POST", "/v1/orders/#{encoded}/process", Mercadopago.Order, :process, [id]},
      {"POST", "/v1/orders/#{encoded}/refund", Mercadopago.Order, :refund, [id]},
      {"POST", "/v1/orders/#{encoded}/cancel", Mercadopago.Order, :cancel, [id]},
      {"POST", "/v1/orders/#{encoded}/capture", Mercadopago.Order, :capture, [id]},
      {"POST", "/v1/orders/#{encoded}/transactions", Mercadopago.OrderTransaction, :create,
       [id, data]},
      {"PUT", "/v1/orders/#{encoded}/transactions/#{encoded}", Mercadopago.OrderTransaction,
       :update, [id, id, data]},
      {"DELETE", "/v1/orders/#{encoded}/transactions/#{encoded}", Mercadopago.OrderTransaction,
       :delete, [id, id]},
      {"GET", "/v1/payments/#{encoded}", Mercadopago.Payment, :get, [id]},
      {"PUT", "/v1/payments/#{encoded}", Mercadopago.Payment, :update, [id, data]},
      {"PUT", "/v1/payments/#{encoded}", Mercadopago.Payment, :capture, [id]},
      {"POST", "/point/integration-api/devices/#{encoded}/payment-intents", Mercadopago.Point,
       :create, [id, data]},
      {"GET", "/point/integration-api/payment-intents/#{encoded}", Mercadopago.Point, :get, [id]},
      {"DELETE", "/point/integration-api/devices/#{encoded}/payment-intents/#{encoded}",
       Mercadopago.Point, :cancel, [id, id]},
      {"GET", "/preapproval/#{encoded}", Mercadopago.Preapproval, :get, [id]},
      {"PUT", "/preapproval/#{encoded}", Mercadopago.Preapproval, :update, [id, data]},
      {"GET", "/preapproval/#{encoded}", Mercadopago.Subscription, :get, [id]},
      {"PUT", "/preapproval/#{encoded}", Mercadopago.Subscription, :update, [id, data]},
      {"GET", "/preapproval_plan/#{encoded}", Mercadopago.PreapprovalPlan, :get, [id]},
      {"PUT", "/preapproval_plan/#{encoded}", Mercadopago.PreapprovalPlan, :update, [id, data]},
      {"GET", "/checkout/preferences/#{encoded}", Mercadopago.Preference, :get, [id]},
      {"PUT", "/checkout/preferences/#{encoded}", Mercadopago.Preference, :update, [id, data]},
      {"GET", "/v1/payments/#{encoded}/refunds", Mercadopago.Refund, :list, [id]},
      {"GET", "/v1/payments/#{encoded}/refunds/#{encoded}", Mercadopago.Refund, :get, [id, id]},
      {"POST", "/v1/payments/#{encoded}/refunds", Mercadopago.Refund, :create, [id]}
    ]
  end
end
