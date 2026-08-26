defmodule Mercadopago.Pagination do
  @moduledoc """
  Lazily walks every page of a search endpoint.

  MercadoPago paginates search results with `limit` and `offset`. `stream/3`
  drives that loop for you and yields the individual records, fetching the next
  page only when the consumer asks for it:

      client
      |> Mercadopago.Payment.search_stream(%{status: "approved"})
      |> Stream.filter(&(&1["transaction_amount"] > 100))
      |> Enum.take(20)

  Because it is a `Stream`, nothing is requested until the pipeline runs, and a
  `Enum.take/2` stops after the pages it actually needed.

  Every resource with a `search/3` exposes a `search_stream/3` that calls this;
  reach for `stream/3` directly only for an endpoint that has none.

  ## Failures are raised, not yielded

  A stream has no place to put an error tuple, so a request that fails mid-walk
  raises: `Mercadopago.Error` for a status of 400 or above, and the underlying
  transport exception (e.g. `Req.TransportError`) for a connection failure. Wrap
  the pipeline in a `try` if a partial result is still useful to you.
  """

  alias Mercadopago.{Error, HTTP}

  @default_page_size 100

  @typedoc "A one-argument search function: takes the filters, returns a response."
  @type search_fun :: (map() -> HTTP.response())

  @doc """
  Streams every record matching `filters` across all pages.

  `search_fun` takes a filters map and returns a `t:Mercadopago.HTTP.response/0`
  — typically a captured resource call, `&Mercadopago.Payment.search(client, &1)`.

  `filters` is sent as query-string parameters. Any `limit`/`offset` in it is
  replaced: `limit` by the page size, `offset` by the walk's position. Pass
  `offset` to start partway through.

  ## Options

    * `:page_size` - records per request (default: #{@default_page_size})

  """
  @spec stream(search_fun(), map() | nil, keyword()) :: Enumerable.t()
  def stream(search_fun, filters \\ nil, opts \\ []) when is_function(search_fun, 1) do
    page_size = Keyword.get(opts, :page_size, @default_page_size)
    filters = stringify_keys(filters || %{})
    start = %{offset: starting_offset(filters), total: nil}

    Stream.resource(
      fn -> start end,
      &next_page(&1, search_fun, filters, page_size),
      fn _state -> :ok end
    )
  end

  defp next_page(:halt, _search_fun, _filters, _page_size), do: {:halt, :halt}

  defp next_page(%{offset: offset} = state, search_fun, filters, page_size) do
    body =
      filters
      |> Map.merge(%{"limit" => page_size, "offset" => offset})
      |> search_fun.()
      |> body!()

    items = extract_items(body)
    total = state.total || extract_total(body)
    next_offset = offset + length(items)

    cond do
      items == [] -> {:halt, :halt}
      last_page?(items, page_size, next_offset, total) -> {items, :halt}
      true -> {items, %{offset: next_offset, total: total}}
    end
  end

  # A short page means the endpoint has nothing more to give, whatever `total`
  # claims — that also keeps a server that ignores `offset` from looping forever.
  defp last_page?(items, page_size, next_offset, total) do
    length(items) < page_size or (is_integer(total) and total > 0 and next_offset >= total)
  end

  defp body!({:ok, %{status: status, response: body}}) when status < 400, do: body

  defp body!({:ok, %{status: status, response: body} = response}) do
    raise Error.new(status, body,
            request_id: response[:request_id],
            retry_after: response[:retry_after]
          )
  end

  defp body!({:error, %{__exception__: true} = exception}), do: raise(exception)

  defp body!({:error, reason}) do
    raise "MercadoPago request failed while paginating: #{inspect(reason)}"
  end

  # Search endpoints disagree on the key: "results" almost everywhere, "data" on
  # the Orders v2 API, "elements" on some Order responses.
  defp extract_items(body) when is_map(body) do
    Enum.find_value(["results", "data", "elements"], [], fn key ->
      case Map.get(body, key) do
        items when is_list(items) -> items
        _other -> nil
      end
    end)
  end

  defp extract_items(_body), do: []

  # Orders v2 sends the total as a string ("181"); everything else as an integer.
  defp extract_total(body) when is_map(body) do
    case body |> Map.get("paging", %{}) |> get_in_map("total") do
      total when is_integer(total) -> total
      total when is_binary(total) -> parse_total(total)
      _other -> nil
    end
  end

  defp extract_total(_body), do: nil

  defp get_in_map(paging, key) when is_map(paging), do: Map.get(paging, key)
  defp get_in_map(_paging, _key), do: nil

  defp parse_total(total) do
    case Integer.parse(total) do
      {parsed, ""} -> parsed
      _other -> nil
    end
  end

  defp starting_offset(filters) do
    case Map.get(filters, "offset") do
      offset when is_integer(offset) and offset >= 0 -> offset
      offset when is_binary(offset) -> parse_total(offset) || 0
      _other -> 0
    end
  end

  # Filters only ever become query-string parameters, so normalising the key
  # style here is invisible on the wire — and it stops a caller's `:limit` and
  # our `"limit"` from both being sent.
  defp stringify_keys(filters) do
    Map.new(filters, fn {key, value} -> {to_string(key), value} end)
  end
end
