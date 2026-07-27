defmodule Mercadopago.Test.IntegrationClient do
  @moduledoc """
  Builds the client used by the integration suite, from `ACCESS_TOKEN`.

  The retry budget is deliberately tighter than the SDK defaults so that the
  worst case of a test stays below ExUnit's 60s per-test timeout. With the
  library defaults (60s timeout, 3 attempts) a flaky sandbox would blow past
  that budget and ExUnit would kill the test with an opaque timeout instead of
  letting the SDK's own error surface.

  Worst case per call: 2 attempts * 10s + one capped backoff of ~2s, so a test
  doing two sequential calls still lands around 45s.
  """

  @doc "Client for integration tests. `opts` override the tightened defaults."
  def new(opts \\ []) do
    defaults = [timeout: 10_000, max_retries: 2, max_retry_delay: 2_000]

    Mercadopago.new(System.fetch_env!("ACCESS_TOKEN"), Keyword.merge(defaults, opts))
  end
end
