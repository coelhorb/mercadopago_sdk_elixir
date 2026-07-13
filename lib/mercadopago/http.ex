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
  """

  import Bitwise

  alias Mercadopago.{Client, Config}

  @retryable_statuses [429, 500, 502, 503, 504]

  @typedoc """
  Result of an API call. `{:ok, ...}` carries the HTTP status and the parsed
  JSON body (a map, a list, or `nil` for empty bodies). `{:error, reason}` is
  returned for transport-level failures (timeouts, connection errors).
  """
  @type response ::
          {:ok, %{status: non_neg_integer(), response: map() | list() | nil}}
          | {:error, term()}

  @doc "GET request with optional query params and per-call opts."
  @spec get(Client.t(), String.t(), map() | nil, keyword()) :: response()
  def get(%Client{} = client, uri, params \\ nil, opts \\ []) do
    headers = build_headers(client, opts)
    url = Config.api_base_url() <> uri
    timeout = opts[:timeout] || client.timeout
    max_retries = opts[:max_retries] || client.max_retries
    do_get(url, headers, params, timeout, max_retries, 0, base_opts(client))
  end

  @doc "POST request. Omit `body` or pass `nil` to send no body."
  @spec post(Client.t(), String.t(), map() | nil, keyword()) :: response()
  def post(%Client{} = client, uri, body, opts \\ []) do
    headers = build_headers(client, opts)
    url = Config.api_base_url() <> uri
    req_opts = base_opts(client) ++ [headers: headers, receive_timeout: timeout(client, opts)]
    req_opts = if body, do: Keyword.put(req_opts, :json, body), else: req_opts
    execute(:post, url, req_opts)
  end

  @doc "PUT request."
  @spec put(Client.t(), String.t(), map() | nil, keyword()) :: response()
  def put(%Client{} = client, uri, body, opts \\ []) do
    headers = build_headers(client, opts)
    url = Config.api_base_url() <> uri

    execute(
      :put,
      url,
      base_opts(client) ++ [headers: headers, json: body, receive_timeout: timeout(client, opts)]
    )
  end

  @doc "DELETE request."
  @spec delete(Client.t(), String.t(), keyword()) :: response()
  def delete(%Client{} = client, uri, opts \\ []) do
    headers = build_headers(client, opts)
    url = Config.api_base_url() <> uri

    execute(
      :delete,
      url,
      base_opts(client) ++ [headers: headers, receive_timeout: timeout(client, opts)]
    )
  end

  defp do_get(url, headers, params, timeout, max_retries, attempt, base_opts) do
    req_opts = base_opts ++ [headers: headers, receive_timeout: timeout]
    req_opts = if params, do: Keyword.put(req_opts, :params, params), else: req_opts

    case execute(:get, url, req_opts) do
      {:ok, %{status: status}}
      when status in @retryable_statuses and attempt < max_retries - 1 ->
        Process.sleep(1_000)
        do_get(url, headers, params, timeout, max_retries, attempt + 1, base_opts)

      other ->
        other
    end
  end

  defp timeout(%Client{} = client, opts), do: opts[:timeout] || client.timeout

  # Req's built-in retry is disabled: the Ruby SDK's retry policy (GET only,
  # fixed 1s pause, specific statuses) is replicated in do_get/7.
  defp base_opts(%Client{} = client) do
    opts = [retry: false]
    opts = if client.finch, do: [finch: client.finch] ++ opts, else: opts
    if client.plug, do: [plug: client.plug] ++ opts, else: opts
  end

  defp execute(method, url, req_opts) do
    case Req.request(Keyword.merge([method: method, url: url], req_opts)) do
      {:ok, %{status: status, body: body}} ->
        {:ok, %{status: status, response: normalize_body(body)}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp normalize_body(""), do: nil
  defp normalize_body(body), do: body

  defp build_headers(%Client{} = client, opts) do
    token = opts[:access_token] || client.access_token

    base = %{
      "Authorization" => "Bearer #{token}",
      "x-product-id" => Config.product_id(),
      "x-tracking-id" => Config.tracking_id(),
      "x-idempotency-key" => generate_idempotency_key(),
      "User-Agent" => Config.user_agent(),
      "Accept" => "application/json"
    }

    partner =
      %{}
      |> put_if(client.corporation_id, "x-corporation-id", client.corporation_id)
      |> put_if(client.integrator_id, "x-integrator-id", client.integrator_id)
      |> put_if(client.platform_id, "x-platform-id", client.platform_id)

    base
    |> Map.merge(partner)
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

  # Canonical UUID v4, matching the Ruby SDK's SecureRandom.uuid.
  defp generate_idempotency_key do
    <<a::32, b::16, c::16, d::16, e::48>> = :crypto.strong_rand_bytes(16)
    c = c |> band(0x0FFF) |> bor(0x4000)
    d = d |> band(0x3FFF) |> bor(0x8000)

    :io_lib.format("~8.16.0b-~4.16.0b-~4.16.0b-~4.16.0b-~12.16.0b", [a, b, c, d, e])
    |> IO.iodata_to_binary()
  end
end
