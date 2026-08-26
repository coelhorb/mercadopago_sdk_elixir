defmodule Mercadopago.Client do
  @moduledoc "Holds authentication and request configuration for all SDK calls."

  # Transient statuses worth another attempt. Overridable per client and per
  # call via `:retry_on`; transport failures are retried independently of it.
  @default_retry_on [429, 500, 502, 503, 504]

  @doc "The statuses a GET is retried on when `:retry_on` is not given."
  @spec default_retry_on() :: [non_neg_integer()]
  def default_retry_on, do: @default_retry_on

  defstruct [
    :access_token,
    :plug,
    :finch,
    timeout: 60_000,
    max_retries: 3,
    retry_delay: 1_000,
    max_retry_delay: 8_000,
    retry_on: @default_retry_on,
    custom_headers: %{},
    corporation_id: nil,
    integrator_id: nil,
    platform_id: nil
  ]

  @type t :: %__MODULE__{
          access_token: String.t() | nil,
          plug: term() | nil,
          finch: atom() | nil,
          timeout: non_neg_integer(),
          max_retries: non_neg_integer(),
          retry_delay: non_neg_integer(),
          max_retry_delay: non_neg_integer(),
          retry_on: [non_neg_integer()],
          custom_headers: map(),
          corporation_id: String.t() | nil,
          integrator_id: String.t() | nil,
          platform_id: String.t() | nil
        }
end
