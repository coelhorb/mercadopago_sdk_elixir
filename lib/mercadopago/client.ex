defmodule Mercadopago.Client do
  @moduledoc "Holds authentication and request configuration for all SDK calls."

  defstruct [
    :access_token,
    :plug,
    :finch,
    timeout: 60_000,
    max_retries: 3,
    retry_delay: 1_000,
    max_retry_delay: 8_000,
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
          custom_headers: map(),
          corporation_id: String.t() | nil,
          integrator_id: String.t() | nil,
          platform_id: String.t() | nil
        }
end
