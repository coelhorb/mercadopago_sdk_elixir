defmodule Mercadopago.PaginationTest do
  use ExUnit.Case, async: true

  import Mercadopago.Test.StubClient, only: [new: 1]

  alias Mercadopago.{Error, Pagination}

  # Serves `pages` in order, recording the query string of each request so the
  # tests can assert on the limit/offset the stream actually sent.
  defp stub_pages(name, pages, test_pid \\ nil) do
    {:ok, counter} = Agent.start_link(fn -> 0 end)

    Req.Test.stub(name, fn conn ->
      index = Agent.get_and_update(counter, &{&1, &1 + 1})
      if test_pid, do: send(test_pid, {:query, conn.query_string})

      Req.Test.json(conn, Enum.at(pages, index, %{"results" => []}))
    end)
  end

  describe "stream/3" do
    test "walks every page and yields the records in order" do
      stub_pages(:paging_results, [
        %{"results" => [%{"id" => 1}, %{"id" => 2}], "paging" => %{"total" => 3}},
        %{"results" => [%{"id" => 3}], "paging" => %{"total" => 3}}
      ])

      client = new(:paging_results)

      assert [%{"id" => 1}, %{"id" => 2}, %{"id" => 3}] =
               client |> Mercadopago.Payment.search_stream(nil, page_size: 2) |> Enum.to_list()
    end

    test "sends the page size as limit and advances the offset" do
      stub_pages(
        :paging_offsets,
        [
          %{"results" => [%{"id" => 1}, %{"id" => 2}], "paging" => %{"total" => 4}},
          %{"results" => [%{"id" => 3}, %{"id" => 4}], "paging" => %{"total" => 4}}
        ],
        self()
      )

      client = new(:paging_offsets)

      Mercadopago.Payment.search_stream(client, %{status: "approved"}, page_size: 2)
      |> Enum.to_list()

      assert_received {:query, first}
      assert_received {:query, second}
      assert URI.decode_query(first) == %{"limit" => "2", "offset" => "0", "status" => "approved"}

      assert URI.decode_query(second) == %{
               "limit" => "2",
               "offset" => "2",
               "status" => "approved"
             }
    end

    test "reads the Orders v2 shape: a data key and a string total" do
      stub_pages(:paging_orders_v2, [
        %{"data" => [%{"id" => "ORD1"}], "paging" => %{"total" => "2"}},
        %{"data" => [%{"id" => "ORD2"}], "paging" => %{"total" => "2"}}
      ])

      client = new(:paging_orders_v2)

      assert [%{"id" => "ORD1"}, %{"id" => "ORD2"}] =
               client |> Mercadopago.Order.search_stream(nil, page_size: 1) |> Enum.to_list()
    end

    test "reads the elements key" do
      stub_pages(:paging_elements, [%{"elements" => [%{"id" => 7}]}])

      client = new(:paging_elements)

      assert [%{"id" => 7}] =
               client |> Mercadopago.Order.search_stream(nil, page_size: 5) |> Enum.to_list()
    end

    test "stops on an empty page even when total lies" do
      stub_pages(:paging_empty, [
        %{"results" => [%{"id" => 1}], "paging" => %{"total" => 99}},
        %{"results" => [], "paging" => %{"total" => 99}}
      ])

      client = new(:paging_empty)

      assert [%{"id" => 1}] =
               client |> Mercadopago.Payment.search_stream(nil, page_size: 1) |> Enum.to_list()
    end

    test "fetches only the pages the consumer asks for" do
      stub_pages(
        :paging_lazy,
        [
          %{"results" => [%{"id" => 1}, %{"id" => 2}], "paging" => %{"total" => 100}},
          %{"results" => [%{"id" => 3}, %{"id" => 4}], "paging" => %{"total" => 100}}
        ],
        self()
      )

      client = new(:paging_lazy)

      assert [%{"id" => 1}] =
               client |> Mercadopago.Payment.search_stream(nil, page_size: 2) |> Enum.take(1)

      assert_received {:query, _first}
      refute_received {:query, _second}
    end

    test "honours an offset supplied in the filters" do
      stub_pages(:paging_start_offset, [%{"results" => [%{"id" => 5}]}], self())

      client = new(:paging_start_offset)
      Mercadopago.Payment.search_stream(client, %{offset: 40}, page_size: 10) |> Enum.to_list()

      assert_received {:query, query}
      assert URI.decode_query(query) == %{"limit" => "10", "offset" => "40"}
    end

    test "raises Mercadopago.Error when a page comes back as an API error" do
      Req.Test.stub(:paging_api_error, fn conn ->
        conn
        |> Plug.Conn.put_status(500)
        |> Req.Test.json(%{"message" => "boom"})
      end)

      client = new(:paging_api_error)

      assert_raise Error, ~r/boom \(HTTP 500\)/, fn ->
        client
        |> Mercadopago.Payment.search_stream(nil, max_retries: 1)
        |> Enum.to_list()
      end
    end

    test "re-raises the transport exception on a connection failure" do
      Req.Test.stub(:paging_transport_error, fn conn ->
        Req.Test.transport_error(conn, :econnrefused)
      end)

      client = new(:paging_transport_error)

      assert_raise Req.TransportError, fn ->
        client
        |> Mercadopago.Payment.search_stream(nil, max_retries: 1)
        |> Enum.to_list()
      end
    end

    test "yields nothing when the first page is empty" do
      stub_pages(:paging_none, [%{"results" => []}])

      assert [] = new(:paging_none) |> Mercadopago.Payment.search_stream() |> Enum.to_list()
    end

    test "stream/3 accepts a bare search function" do
      stub_pages(:paging_bare, [%{"results" => [%{"id" => 1}]}])
      client = new(:paging_bare)

      assert [%{"id" => 1}] =
               Pagination.stream(&Mercadopago.Payment.search(client, &1), nil, page_size: 10)
               |> Enum.to_list()
    end
  end
end
