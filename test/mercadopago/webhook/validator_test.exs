defmodule Mercadopago.Webhook.ValidatorTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias Mercadopago.Webhook.Validator
  alias Mercadopago.Webhook.Validator.InvalidSignatureError

  @secret "test_secret"
  # Seconds since the epoch, as MercadoPago sends it in the x-signature header.
  @ts "1704067200"
  @data_id "123"
  @request_id "req-abc"

  defp sign(manifest, secret \\ @secret) do
    :crypto.mac(:hmac, :sha256, secret, manifest) |> Base.encode16(case: :lower)
  end

  defp header(ts, hash, version \\ "v1"), do: "ts=#{ts},#{version}=#{hash}"

  defp valid_manifest(data_id, request_id, ts) do
    parts = []
    parts = if data_id, do: ["id:#{data_id}" | parts], else: parts
    parts = if request_id, do: ["request-id:#{request_id}" | parts], else: parts
    parts = ["ts:#{ts}" | parts]
    (Enum.reverse(parts) |> Enum.join(";")) <> ";"
  end

  defp valid_header(data_id \\ @data_id, request_id \\ @request_id, ts \\ @ts) do
    manifest = valid_manifest(data_id, request_id, ts)
    header(ts, sign(manifest))
  end

  describe "validate/5 — success" do
    test "returns {:ok, ts} for a valid signature" do
      assert {:ok, @ts} = Validator.validate(valid_header(), @request_id, @data_id, @secret)
    end

    test "returns {:ok, ts} when data_id is nil (omitted from manifest)" do
      x_sig = valid_header(nil, @request_id, @ts)
      assert {:ok, @ts} = Validator.validate(x_sig, @request_id, nil, @secret)
    end

    test "returns {:ok, ts} when x_request_id is nil (omitted from manifest)" do
      x_sig = valid_header(@data_id, nil, @ts)
      assert {:ok, @ts} = Validator.validate(x_sig, nil, @data_id, @secret)
    end

    test "returns {:ok, ts} when both data_id and x_request_id are nil" do
      x_sig = valid_header(nil, nil, @ts)
      assert {:ok, @ts} = Validator.validate(x_sig, nil, nil, @secret)
    end

    test "strips whitespace from x_signature before parsing" do
      x_sig = "  #{valid_header()}  "
      assert {:ok, @ts} = Validator.validate(x_sig, @request_id, @data_id, @secret)
    end

    test "accepts the first matching version in the header" do
      manifest = valid_manifest(@data_id, @request_id, @ts)
      hash = sign(manifest)
      x_sig = "ts=#{@ts},v2=irrelevant,v1=#{hash}"

      assert {:ok, @ts} =
               Validator.validate(x_sig, @request_id, @data_id, @secret,
                 supported_versions: ["v1"]
               )
    end

    test "accepts custom supported_versions" do
      manifest = valid_manifest(@data_id, @request_id, @ts)
      hash = sign(manifest)
      x_sig = "ts=#{@ts},v2=#{hash}"

      assert {:ok, @ts} =
               Validator.validate(x_sig, @request_id, @data_id, @secret,
                 supported_versions: ["v2"]
               )
    end

    test "accepts an uppercase Orders data_id against a lowercased manifest" do
      # MercadoPago's documented example: the notification carries
      # ORD01JQ4S4KY8HWQ6NA5PXB65B3D3 but signs ord01jq4s4ky8hwq6na5pxb65b3d3.
      sent_id = "ORD01JQ4S4KY8HWQ6NA5PXB65B3D3"
      signed_manifest = valid_manifest(String.downcase(sent_id), @request_id, @ts)
      x_sig = header(@ts, sign(signed_manifest))

      assert {:ok, @ts} = Validator.validate(x_sig, @request_id, sent_id, @secret)
    end

    test "accepts a mixed-case data_id against a lowercased manifest" do
      sent_id = "OrD01jQ4s4Ky8H"
      signed_manifest = valid_manifest(String.downcase(sent_id), @request_id, @ts)
      x_sig = header(@ts, sign(signed_manifest))

      assert {:ok, @ts} = Validator.validate(x_sig, @request_id, sent_id, @secret)
    end

    test "numeric data_id signing is unchanged by the lowercasing rule" do
      # Regression guard: digits have no case, so the manifest must be
      # byte-identical to what it was before lowercasing was introduced.
      x_sig = header(@ts, sign("id:123;request-id:#{@request_id};ts:#{@ts};"))

      assert {:ok, @ts} = Validator.validate(x_sig, @request_id, "123", @secret)
    end

    test "rejects a signature computed over a non-lowercased data_id" do
      sent_id = "ORD01JQ4S4KY8HWQ6NA5PXB65B3D3"
      x_sig = header(@ts, sign(valid_manifest(sent_id, @request_id, @ts)))

      assert {:error, %InvalidSignatureError{reason: :signature_mismatch}} =
               Validator.validate(x_sig, @request_id, sent_id, @secret)
    end

    test "timestamp tolerance passes when drift is within limit" do
      now_ms = String.to_integer(@ts) * 1_000 + 100_000
      now_fn = fn -> now_ms end

      assert {:ok, @ts} =
               Validator.validate(valid_header(), @request_id, @data_id, @secret,
                 tolerance_seconds: 200,
                 now: now_fn
               )
    end

    # Regression: `ts` is in seconds and the default clock is in milliseconds.
    # Comparing them unscaled makes a fresh notification look ~55 years stale,
    # so every webhook validated with a tolerance was rejected.
    test "a fresh notification passes against the real millisecond clock" do
      now_seconds = System.system_time(:second)
      ts = Integer.to_string(now_seconds - 5)

      assert {:ok, ^ts} =
               Validator.validate(
                 valid_header(@data_id, @request_id, ts),
                 @request_id,
                 @data_id,
                 @secret,
                 tolerance_seconds: 300
               )
    end
  end

  describe "validate/5 — missing_signature_header" do
    test "errors when x_signature is nil" do
      assert {:error, %InvalidSignatureError{reason: :missing_signature_header}} =
               Validator.validate(nil, @request_id, @data_id, @secret)
    end

    test "errors when x_signature is blank" do
      assert {:error, %InvalidSignatureError{reason: :missing_signature_header}} =
               Validator.validate("   ", @request_id, @data_id, @secret)
    end
  end

  describe "validate/5 — malformed_signature_header" do
    test "errors when header has no ts and no version hashes" do
      assert {:error, %InvalidSignatureError{reason: :malformed_signature_header}} =
               Validator.validate("garbage", @request_id, @data_id, @secret)
    end

    test "errors when ts is non-numeric" do
      x_sig = "ts=not-a-number,v1=#{sign("irrelevant")}"

      assert {:error, %InvalidSignatureError{reason: :malformed_signature_header}} =
               Validator.validate(x_sig, @request_id, @data_id, @secret)
    end
  end

  describe "validate/5 — missing_timestamp" do
    test "errors when header has version hash but no ts" do
      x_sig = "v1=#{sign("irrelevant")}"

      assert {:error, %InvalidSignatureError{reason: :missing_timestamp}} =
               Validator.validate(x_sig, @request_id, @data_id, @secret)
    end
  end

  describe "validate/5 — missing_hash" do
    test "errors when supported version is not present in header" do
      x_sig = "ts=#{@ts},v2=#{sign("irrelevant")}"

      assert {:error, %InvalidSignatureError{reason: :missing_hash}} =
               Validator.validate(x_sig, @request_id, @data_id, @secret)
    end
  end

  describe "validate/5 — signature_mismatch" do
    test "errors when HMAC does not match" do
      assert {:error, %InvalidSignatureError{reason: :signature_mismatch}} =
               Validator.validate(valid_header(), @request_id, @data_id, "wrong_secret")
    end

    test "errors when hash is correct length but wrong value" do
      fake_hash = String.duplicate("a", 64)
      x_sig = header(@ts, fake_hash)

      assert {:error, %InvalidSignatureError{reason: :signature_mismatch}} =
               Validator.validate(x_sig, @request_id, @data_id, @secret)
    end
  end

  describe "validate/5 — a :now in the wrong unit" do
    # The pre-0.3.0 workaround (a :now in seconds) does not silently widen the
    # window once the unit is fixed — it rejects everything. The warning is what
    # tells the integrator why their webhooks stopped, instead of a bare
    # :timestamp_out_of_tolerance.
    test "warns and rejects when the clock looks like seconds rather than milliseconds" do
      now_seconds = System.system_time(:second)
      ts = Integer.to_string(now_seconds - 5)

      log =
        capture_log(fn ->
          assert {:error, %InvalidSignatureError{reason: :timestamp_out_of_tolerance}} =
                   Validator.validate(
                     valid_header(@data_id, @request_id, ts),
                     @request_id,
                     @data_id,
                     @secret,
                     tolerance_seconds: 300,
                     now: fn -> now_seconds end
                   )
        end)

      assert log =~ "looks like seconds, not milliseconds"
    end

    test "stays quiet for a millisecond clock" do
      log =
        capture_log(fn ->
          Validator.validate(valid_header(), @request_id, @data_id, @secret,
            tolerance_seconds: 300,
            now: fn -> String.to_integer(@ts) * 1_000 end
          )
        end)

      refute log =~ "milliseconds"
    end

    test "stays quiet when no tolerance is configured" do
      log =
        capture_log(fn ->
          assert {:ok, @ts} = Validator.validate(valid_header(), @request_id, @data_id, @secret)
        end)

      refute log =~ "milliseconds"
    end
  end

  describe "validate/5 — timestamp_out_of_tolerance" do
    test "errors when drift exceeds tolerance" do
      now_ms = String.to_integer(@ts) * 1_000 + 400_000
      now_fn = fn -> now_ms end

      assert {:error, %InvalidSignatureError{reason: :timestamp_out_of_tolerance}} =
               Validator.validate(valid_header(), @request_id, @data_id, @secret,
                 tolerance_seconds: 300,
                 now: now_fn
               )
    end
  end

  describe "validate/5 — error attributes" do
    test "error carries request_id for log correlation" do
      assert {:error, %InvalidSignatureError{request_id: @request_id}} =
               Validator.validate(nil, @request_id, @data_id, @secret)
    end

    test "error message mentions the reason" do
      assert {:error, %InvalidSignatureError{message: message}} =
               Validator.validate(nil, @request_id, @data_id, @secret)

      assert message =~ "missing_signature_header"
    end
  end

  describe "validate/5 — ArgumentError" do
    test "raises ArgumentError when secret is nil" do
      assert_raise ArgumentError, "secret must not be empty", fn ->
        # credo:disable-for-next-line Credo.Check.Refactor.Apply
        apply(Validator, :validate, [valid_header(), @request_id, @data_id, nil])
      end
    end

    test "raises ArgumentError when secret is empty string" do
      assert_raise ArgumentError, "secret must not be empty", fn ->
        Validator.validate(valid_header(), @request_id, @data_id, "")
      end
    end
  end

  describe "validate!/5" do
    test "returns :ok for a valid signature" do
      assert :ok = Validator.validate!(valid_header(), @request_id, @data_id, @secret)
    end

    test "raises InvalidSignatureError on failure" do
      err =
        assert_raise(InvalidSignatureError, fn ->
          Validator.validate!(valid_header(), @request_id, @data_id, "wrong_secret")
        end)

      assert err.reason == :signature_mismatch
    end
  end
end
