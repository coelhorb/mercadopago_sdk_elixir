defmodule Mercadopago.Webhook.Validator do
  @moduledoc """
  Validates MercadoPago webhook signatures (HMAC-SHA256).

  Call `validate/5` on every incoming webhook. It returns `{:ok, ts}` on success
  and `{:error, %InvalidSignatureError{}}` on failure — an invalid signature is
  an expected outcome for any public endpoint, so it is reported as data, not by
  raising. Use `validate!/5` when you prefer a raising variant.

  QR Code notifications are not signed by MercadoPago — do not call this
  validator for those events.

  ## Example

      case Mercadopago.Webhook.Validator.validate(
             conn.req_headers |> Map.new() |> Map.get("x-signature"),
             conn.req_headers |> Map.new() |> Map.get("x-request-id"),
             conn.params["data"]["id"],
             webhook_secret,
             tolerance_seconds: 300
           ) do
        {:ok, _ts} -> send_resp(conn, 200, "")
        {:error, %InvalidSignatureError{} = e} -> send_resp(conn, 401, e.message)
      end

  Raising variant:

      :ok = Mercadopago.Webhook.Validator.validate!(x_sig, x_req, data_id, secret)
  """

  defmodule InvalidSignatureError do
    @moduledoc "Returned (or raised by `validate!/5`) when a webhook signature cannot be verified."
    defexception [:reason, :request_id, :timestamp, :message]

    @type t :: %__MODULE__{
            reason: atom(),
            request_id: String.t() | nil,
            timestamp: String.t() | nil,
            message: String.t()
          }

    @impl true
    def exception(opts) do
      reason = opts[:reason]

      struct!(__MODULE__,
        reason: reason,
        request_id: opts[:request_id],
        timestamp: opts[:timestamp],
        message: "Invalid webhook signature: #{reason}"
      )
    end
  end

  @default_versions ["v1"]
  @version_regex ~r/\Av\d+\z/

  @doc """
  Validates the signature of a MercadoPago webhook notification.

  ## Arguments

    * `x_signature` - raw value of the `x-signature` request header
    * `x_request_id` - value of the `x-request-id` header (may be nil)
    * `data_id` - value of the `data.id` query parameter (may be nil)
    * `secret` - HMAC key configured in Tus Integraciones

  ## Options

    * `:tolerance_seconds` - max allowed drift between header timestamp and now
    * `:supported_versions` - list of accepted signature versions (default: `["v1"]`)
    * `:now` - zero-arity function returning current time in milliseconds (for testing)

  ## Returns

    `{:ok, ts}` on success (where `ts` is the verified timestamp string),
    `{:error, %InvalidSignatureError{}}` on failure. Raises `ArgumentError`
    when `secret` is missing — that is a caller misconfiguration, not webhook
    input.
  """
  @spec validate(
          String.t() | nil,
          String.t() | nil,
          String.t() | nil,
          String.t(),
          keyword()
        ) :: {:ok, String.t()} | {:error, InvalidSignatureError.t()}
  def validate(x_signature, x_request_id, data_id, secret, opts \\ []) do
    if is_nil(secret) or secret == "", do: raise(ArgumentError, "secret must not be empty")

    x_sig = normalize(x_signature)
    x_req = normalize(x_request_id)
    d_id = normalize(data_id)
    versions = resolve_versions(opts[:supported_versions])
    now_fn = Keyword.get(opts, :now, fn -> :os.system_time(:millisecond) end)
    tolerance = opts[:tolerance_seconds]

    with {:ok, {ts, received_hash}} <- parse_header(x_sig, x_req, versions),
         :ok <- verify_signature(d_id, x_req, ts, secret, received_hash),
         :ok <- check_tolerance(ts, x_req, tolerance, now_fn) do
      {:ok, ts}
    end
  end

  @doc """
  Like `validate/5`, but returns `:ok` on success and raises
  `InvalidSignatureError` on failure.
  """
  @spec validate!(
          String.t() | nil,
          String.t() | nil,
          String.t() | nil,
          String.t(),
          keyword()
        ) :: :ok
  def validate!(x_signature, x_request_id, data_id, secret, opts \\ []) do
    case validate(x_signature, x_request_id, data_id, secret, opts) do
      {:ok, _ts} -> :ok
      {:error, exception} -> raise exception
    end
  end

  defp resolve_versions(nil), do: @default_versions
  defp resolve_versions([]), do: @default_versions
  defp resolve_versions(versions), do: versions

  defp normalize(nil), do: nil

  defp normalize(value) do
    trimmed = String.trim(to_string(value))
    if trimmed == "", do: nil, else: trimmed
  end

  defp parse_header(nil, x_req, _versions) do
    {:error, error(:missing_signature_header, x_req)}
  end

  defp parse_header(x_sig, x_req, versions) do
    {ts, hashes} = parse_signature_header(x_sig)

    with :ok <- validate_timestamp(ts, hashes, x_req),
         {:ok, version} <- find_version(versions, hashes, x_req, ts) do
      {:ok, {ts, Map.fetch!(hashes, version)}}
    end
  end

  defp validate_timestamp(ts, hashes, x_req) do
    cond do
      is_nil(ts) and map_size(hashes) == 0 -> {:error, error(:malformed_signature_header, x_req)}
      is_nil(ts) -> {:error, error(:missing_timestamp, x_req)}
      not Regex.match?(~r/\A\d+\z/, ts) -> {:error, error(:malformed_signature_header, x_req, ts)}
      true -> :ok
    end
  end

  defp find_version(versions, hashes, x_req, ts) do
    case Enum.find(versions, fn v -> Map.has_key?(hashes, v) end) do
      nil -> {:error, error(:missing_hash, x_req, ts)}
      version -> {:ok, version}
    end
  end

  defp parse_signature_header(header) do
    Enum.reduce(String.split(header, ","), {nil, %{}}, fn part, {ts, hashes} ->
      case String.split(part, "=", parts: 2) do
        [key, value] ->
          parse_signature_part(
            String.trim(key) |> String.downcase(),
            String.trim(value),
            ts,
            hashes
          )

        _ ->
          {ts, hashes}
      end
    end)
  end

  defp parse_signature_part(key, value, ts, hashes) do
    cond do
      key == "" or value == "" -> {ts, hashes}
      key == "ts" -> {value, hashes}
      Regex.match?(@version_regex, key) -> {ts, Map.put(hashes, key, value)}
      true -> {ts, hashes}
    end
  end

  defp verify_signature(data_id, x_req, ts, secret, received_hash) do
    manifest = build_manifest(data_id, x_req, ts)
    computed = :crypto.mac(:hmac, :sha256, secret, manifest) |> Base.encode16(case: :lower)

    if constant_time_equal?(computed, received_hash) do
      :ok
    else
      {:error, error(:signature_mismatch, x_req, ts)}
    end
  end

  defp build_manifest(data_id, request_id, timestamp) do
    parts = []
    parts = if data_id, do: ["id:#{data_id}" | parts], else: parts
    parts = if request_id, do: ["request-id:#{request_id}" | parts], else: parts
    parts = ["ts:#{timestamp}" | parts]

    Enum.reverse(parts) |> Enum.flat_map(&[&1, ";"]) |> IO.iodata_to_binary()
  end

  defp check_tolerance(_ts, _x_req, nil, _now_fn), do: :ok

  defp check_tolerance(ts, x_req, tolerance_seconds, now_fn) do
    drift_ms = abs(now_fn.() - String.to_integer(ts))

    if drift_ms > tolerance_seconds * 1_000 do
      {:error, error(:timestamp_out_of_tolerance, x_req, ts)}
    else
      :ok
    end
  end

  defp constant_time_equal?(a, b) when byte_size(a) != byte_size(b), do: false

  defp constant_time_equal?(a, b) do
    :crypto.hash_equals(a, b)
  end

  @spec error(atom(), String.t() | nil) :: InvalidSignatureError.t()
  @spec error(atom(), String.t() | nil, String.t() | nil) :: InvalidSignatureError.t()
  defp error(reason, request_id, timestamp \\ nil) do
    InvalidSignatureError.exception(reason: reason, request_id: request_id, timestamp: timestamp)
  end
end
