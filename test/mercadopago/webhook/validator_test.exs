defmodule Mercadopago.Webhook.ValidatorTest do
  use ExUnit.Case, async: true

  alias Mercadopago.Webhook.Validator
  alias Mercadopago.Webhook.Validator.InvalidSignatureError

  @secret "test_secret"
  @ts "1704067200000"
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

    test "timestamp tolerance passes when drift is within limit" do
      now_ms = String.to_integer(@ts) + 100_000
      now_fn = fn -> now_ms end

      assert {:ok, @ts} =
               Validator.validate(valid_header(), @request_id, @data_id, @secret,
                 tolerance_seconds: 200,
                 now: now_fn
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

  describe "validate/5 — timestamp_out_of_tolerance" do
    test "errors when drift exceeds tolerance" do
      now_ms = String.to_integer(@ts) + 400_000
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
