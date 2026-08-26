defmodule Mercadopago.HTTP do
  @moduledoc """
  Req-based HTTP transport. Retries GET on transient errors; no retry for
  mutating verbs.

  All functions accept per-call `opts` overriding the client configuration:

    * `:access_token` - token for this request only
    * `:custom_headers` - headers merged over the client's `custom_headers`,
      overriding generated headers case-insensitively
    * `:timeout` - receive timeout in milliseconds for this request only
    * `:max_retries` - GET retry budget for this request only
    * `:retry_delay` - base backoff in milliseconds for this request only
    * `:max_retry_delay` - backoff ceiling in milliseconds for this request only
    * `:retry_on` - list of HTTP statuses to retry for this request only

  ## Retry policy

  A GET is retried while the response status is one of `:retry_on` (default
  `#{inspect([429, 500, 502, 503, 504])}`) or the request fails with a retryable
  transport error (a connection closed under the pool, a refused or unreachable
  host). A `:timeout` is never retried: the receive timeout has already spent
  the latency budget. Transport errors are retried regardless of `:retry_on`,
  which only ever narrows or widens the *statuses*.

  Backoff is exponential from `:retry_delay`, doubled per attempt, capped by
  `:max_retry_delay`, plus jitter so that concurrent callers do not come back
  in lockstep after an incident. A `Retry-After` header (delta-seconds form)
  takes precedence, but is capped by `:max_retry_delay` all the same.

  The wait blocks the calling process, so the worst-case latency of a GET is
  roughly `max_retries * timeout` plus the accumulated backoff.

  ## Telemetry

  Every attempt — including each retry — is wrapped in a `:telemetry.span/3`:

    * `[:mercadopago, :request, :start]` - measurements `%{system_time: _}`
    * `[:mercadopago, :request, :stop]` - measurements `%{duration: _}`
    * `[:mercadopago, :request, :exception]` - when the request raises

  Metadata carries `:method`, `:path` and `:attempt` (zero-based), plus
  `:status` on a completed request or `:error` on a transport failure. Neither
  the access token nor the request body is ever included.

  One more event fires just before the SDK sleeps to retry:

    * `[:mercadopago, :request, :retry]` - measurements `%{delay: milliseconds}`,
      the same metadata as above describing the attempt that *failed*

  Attach to it for the equivalent of a per-retry callback — to count retries, or
  to log the status that provoked one.
  """

  import Bitwise

  alias Mercadopago.{Client, Config}

  # Transport failures worth retrying on GET. `:timeout` is deliberately absent.
  @retryable_transport_reasons [:closed, :econnrefused, :ehostunreach]

  @typedoc "A MercadoPago resource identifier. The API returns some ids as integers."
  @type id :: String.t() | non_neg_integer()

  @typedoc """
  Result of an API call. `{:ok, ...}` carries the HTTP status and the response
  body: a map or a list for JSON, `nil` for an empty body, and a raw binary
  when the response is not JSON (an HTML error page from a proxy, for
  instance). `{:error, reason}` is returned for transport-level failures
  (timeouts, connection errors).

  It also carries two diagnostics lifted from the response headers, each `nil`
  when the header was absent: `:request_id` (`x-request-id`, the identifier
  MercadoPago support asks for) and `:retry_after` (`Retry-After`, in seconds).
  """
  @type response ::
          {:ok,
           %{
             status: non_neg_integer(),
             response: map() | list() | binary() | nil,
             request_id: String.t() | nil,
             retry_after: non_neg_integer() | nil
           }}
          | {:error, term()}

  @typedoc """
  A `multipart/form-data` body. Each part is `{name, value}`, where `name` is an
  atom (Req's requirement) and `value` is either a plain binary field or
  `{content, filename: name, content_type: type}` for a file part. `content` may
  be a binary or a stream, so large uploads need not be read into memory.

  Required by endpoints such as chargeback documentation upload:

      {:multipart, [
        {:kind, "invoice"},
        {:file, {File.stream!("proof.pdf", 2048), filename: "proof.pdf",
                 content_type: "application/pdf"}}
      ]}
  """
  @type multipart_body :: {:multipart, [{atom(), term()}]}

  @typedoc "Request body: a JSON-encodable map, a multipart body, or none."
  @type body :: map() | multipart_body() | nil

  @doc """
  Converts a response into idiomatic `{:ok, body}` / `{:error, exception}`.

  A completed request with a status of 400 or above becomes
  `{:error, %Mercadopago.Error{}}`; a success is unwrapped to its body alone.
  Transport failures pass through unchanged, since they are already `{:error, _}`.

      client
      |> Mercadopago.Payment.get(payment_id)
      |> Mercadopago.HTTP.unwrap()

  This is a pure function over an already-returned response, so it is opt-in: the
  resource functions themselves keep returning `{:ok, %{status: _, response: _}}`.
  Reach for it when the status code carries no information you act on.
  """
  @spec unwrap(response()) :: {:ok, map() | list() | binary() | nil} | {:error, term()}
  def unwrap({:ok, %{status: status, response: body} = response}) when status >= 400 do
    {:error,
     Mercadopago.Error.new(status, body,
       request_id: response[:request_id],
       retry_after: response[:retry_after]
     )}
  end

  def unwrap({:ok, %{response: body}}), do: {:ok, body}
  def unwrap({:error, _reason} = error), do: error

  @doc false
  @spec encode_path_param(id()) :: String.t()
  def encode_path_param(value) when is_integer(value), do: Integer.to_string(value)

  def encode_path_param(value) when is_binary(value) and value != "" do
    URI.encode(value, &URI.char_unreserved?/1)
  end

  # A blank id would silently build the collection path (e.g. "/v1/payments/"),
  # hitting a different endpoint instead of failing.
  def encode_path_param(value) do
    raise ArgumentError,
          "path parameter must be a non-empty string or an integer, got: #{inspect(value)}"
  end

  @doc "GET request with optional query params and per-call opts."
  @spec get(Client.t(), String.t(), map() | nil, keyword()) :: response()
  def get(%Client{} = client, uri, params \\ nil, opts \\ []) do
    config = request_config(client, opts)
    req_opts = if params, do: [params: params] ++ config.req_opts, else: config.req_opts

    do_get(Config.api_base_url() <> uri, uri, req_opts, config, 0)
  end

  @doc """
  POST request. Omit `body` or pass `nil` to send no body.

  Pass `{:multipart, parts}` as the body to upload files as `multipart/form-data`
  instead of JSON — see `t:multipart_body/0`.
  """
  @spec post(Client.t(), String.t(), body(), keyword()) :: response()
  def post(%Client{} = client, uri, body, opts \\ []) do
    request(:post, uri, encode_body(body, base_opts(client, opts)))
  end

  @doc "PUT request."
  @spec put(Client.t(), String.t(), body(), keyword()) :: response()
  def put(%Client{} = client, uri, body, opts \\ []) do
    request(:put, uri, encode_body(body, base_opts(client, opts)))
  end

  @doc "PATCH request, for endpoints that accept a partial update."
  @spec patch(Client.t(), String.t(), body(), keyword()) :: response()
  def patch(%Client{} = client, uri, body, opts \\ []) do
    request(:patch, uri, encode_body(body, base_opts(client, opts)))
  end

  @doc "DELETE request."
  @spec delete(Client.t(), String.t(), keyword()) :: response()
  def delete(%Client{} = client, uri, opts \\ []) do
    request(:delete, uri, base_opts(client, opts))
  end

  # Req sets the Content-Type (and the multipart boundary) from whichever of these
  # options is present, so the body shape alone selects the encoding.
  defp encode_body(nil, req_opts), do: req_opts
  defp encode_body({:multipart, parts}, req_opts), do: [form_multipart: parts] ++ req_opts
  defp encode_body(body, req_opts), do: [json: body] ++ req_opts

  defp do_get(url, path, req_opts, config, attempt) do
    result = execute(:get, url, path, req_opts, attempt)

    if attempt < config.max_retries - 1 and retryable?(result, config.retry_on) do
      delay = retry_delay(retry_after_ms(result), attempt, config)
      announce_retry(:get, path, attempt, delay, result)
      Process.sleep(delay)
      do_get(url, path, req_opts, config, attempt + 1)
    else
      to_response(result)
    end
  end

  defp announce_retry(method, path, attempt, delay, result) do
    metadata = %{method: method, path: path, attempt: attempt}

    :telemetry.execute(
      [:mercadopago, :request, :retry],
      %{delay: delay},
      Map.merge(metadata, result_metadata(result))
    )
  end

  defp request(method, uri, req_opts) do
    method
    |> execute(Config.api_base_url() <> uri, uri, req_opts, 0)
    |> to_response()
  end

  defp execute(method, url, path, req_opts, attempt) do
    metadata = %{method: method, path: path, attempt: attempt}

    :telemetry.span([:mercadopago, :request], metadata, fn ->
      result = Req.request([method: method, url: url] ++ req_opts)
      {result, Map.merge(metadata, result_metadata(result))}
    end)
  end

  defp result_metadata({:ok, %{status: status}}), do: %{status: status}
  defp result_metadata({:error, reason}), do: %{error: reason}

  defp retryable?({:ok, %{status: status}}, retry_on), do: status in retry_on

  defp retryable?({:error, %Req.TransportError{reason: reason}}, _retry_on) do
    reason in @retryable_transport_reasons
  end

  defp retryable?({:error, _reason}, _retry_on), do: false

  defp retry_after_ms({:ok, %Req.Response{} = response}) do
    case retry_after_seconds(response) do
      nil -> nil
      seconds -> seconds * 1_000
    end
  end

  defp retry_after_ms({:error, _reason}), do: nil

  # Only the delta-seconds form is understood; the HTTP-date form falls back to
  # exponential backoff and is reported as no `Retry-After` at all.
  defp retry_after_seconds(%Req.Response{} = response) do
    with [value | _rest] <- Req.Response.get_header(response, "retry-after"),
         {seconds, ""} when seconds >= 0 <- Integer.parse(value) do
      seconds
    else
      _other -> nil
    end
  end

  defp retry_after_seconds(_response), do: nil

  defp header(%Req.Response{} = response, name) do
    case Req.Response.get_header(response, name) do
      [value | _rest] -> value
      [] -> nil
    end
  end

  defp header(_response, _name), do: nil

  # Exponential backoff with jitter. `Retry-After` wins when the server sends
  # it, but is capped like any other delay so that a mistaken or hostile value
  # cannot pin the calling process for minutes.
  defp retry_delay(retry_after_ms, attempt, config) do
    delay = min(retry_after_ms || config.retry_delay <<< attempt, config.max_retry_delay)

    delay + :rand.uniform(div(delay, 4) + 1)
  end

  defp to_response({:ok, %{status: status, body: body} = response}) do
    {:ok,
     %{
       status: status,
       response: normalize_body(body),
       request_id: header(response, "x-request-id"),
       retry_after: retry_after_seconds(response)
     }}
  end

  defp to_response({:error, reason}), do: {:error, reason}

  defp normalize_body(""), do: nil
  defp normalize_body(body), do: body

  # Resolves every per-call override once, up front, so that the headers (and
  # therefore the idempotency key) stay identical across retries.
  defp request_config(%Client{} = client, opts) do
    %{
      max_retries: opts[:max_retries] || client.max_retries,
      retry_delay: opts[:retry_delay] || client.retry_delay,
      max_retry_delay: opts[:max_retry_delay] || client.max_retry_delay,
      retry_on: opts[:retry_on] || client.retry_on,
      req_opts: base_opts(client, opts)
    }
  end

  # Req's built-in retry is disabled: the SDK drives its own GET-only policy in
  # do_get/5.
  defp base_opts(%Client{} = client, opts) do
    req_opts = [
      headers: build_headers(client, opts),
      receive_timeout: opts[:timeout] || client.timeout,
      retry: false
    ]

    req_opts = if client.finch, do: [finch: client.finch] ++ req_opts, else: req_opts
    if client.plug, do: [plug: client.plug] ++ req_opts, else: req_opts
  end

  defp build_headers(%Client{} = client, opts) do
    token = opts[:access_token] || client.access_token

    base = %{
      "x-product-id" => Config.product_id(),
      "x-tracking-id" => Config.tracking_id(),
      "x-idempotency-key" => generate_idempotency_key(),
      "User-Agent" => Config.user_agent(),
      "Accept" => "application/json"
    }

    # Authorization is omitted entirely when there is no token, so that the OAuth
    # bootstrap does not send a bare "Bearer " that the API rejects as malformed.
    optional =
      %{}
      |> put_if(blank_to_nil(token), "Authorization", "Bearer #{token}")
      |> put_if(client.corporation_id, "x-corporation-id", client.corporation_id)
      |> put_if(client.integrator_id, "x-integrator-id", client.integrator_id)
      |> put_if(client.platform_id, "x-platform-id", client.platform_id)

    base
    |> Map.merge(optional)
    |> merge_custom_headers(client, opts)
  end

  # Custom headers replace generated ones case-insensitively, so callers can
  # override e.g. "x-idempotency-key" regardless of the casing they use.
  # Per-call custom headers win over the client's under the same rule.
  defp merge_custom_headers(headers, %Client{} = client, opts) do
    custom =
      merge_case_insensitive(
        stringify_names(client.custom_headers || %{}),
        stringify_names(opts[:custom_headers] || %{})
      )

    merge_case_insensitive(headers, custom)
  end

  defp merge_case_insensitive(base, override) when map_size(override) == 0, do: base

  defp merge_case_insensitive(base, override) do
    override_names = MapSet.new(Map.keys(override), &String.downcase/1)

    base
    |> Map.reject(fn {name, _value} -> String.downcase(name) in override_names end)
    |> Map.merge(override)
  end

  defp stringify_names(headers) do
    Map.new(headers, fn {name, value} -> {to_string(name), value} end)
  end

  defp put_if(map, nil, _key, _value), do: map
  defp put_if(map, _truthy, key, value), do: Map.put(map, key, value)

  defp blank_to_nil(nil), do: nil
  defp blank_to_nil(""), do: nil
  defp blank_to_nil(token), do: token

  # Canonical UUID v4, matching the Ruby SDK's SecureRandom.uuid.
  defp generate_idempotency_key do
    <<a::32, b::16, c::16, d::16, e::48>> = :crypto.strong_rand_bytes(16)
    c = c |> band(0x0FFF) |> bor(0x4000)
    d = d |> band(0x3FFF) |> bor(0x8000)

    :io_lib.format("~8.16.0b-~4.16.0b-~4.16.0b-~4.16.0b-~12.16.0b", [a, b, c, d, e])
    |> IO.iodata_to_binary()
  end
end
