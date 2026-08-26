defmodule Mercadopago.FinchTest do
  @moduledoc """
  The `:finch` option is the one request option no other test exercises — every
  other test routes through `:plug`, and the two adapters are mutually
  exclusive. That gap is why Req 0.7's deprecation of `finch: name` reached a
  release unnoticed while the rest of the suite stayed green.
  """

  # capture_io/2 on :stderr is not concurrency-safe.
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  # A pool that was never started fails at the Finch registry lookup, before any
  # socket is opened, so these exercise option handling without leaving the
  # machine. Req normalises (and complains about) the option before it gets there.
  defp capture_request(finch_opt) do
    client = Mercadopago.new("test_token", finch: finch_opt)

    capture_io(:stderr, fn ->
      assert_raise ArgumentError, fn -> Mercadopago.HTTP.get(client, "/v1/anything") end
    end)
  end

  test "the client passes :finch in the shape Req 0.7 expects" do
    refute capture_request(__MODULE__.NoSuchPool) =~ "deprecated"
  end

  # Positive control: without it, the assertion above could pass simply because
  # nothing is ever written to stderr.
  test "Req does warn about the shape this SDK stopped using" do
    stderr =
      capture_io(:stderr, fn ->
        assert_raise ArgumentError, fn ->
          Req.request(
            method: :get,
            url: "https://api.mercadopago.com/v1/anything",
            finch: __MODULE__.NoSuchPool,
            retry: false
          )
        end
      end)

    assert stderr =~ "deprecated"
  end
end
