defmodule Mercadopago.Client do
  @moduledoc "Holds authentication and request configuration for all SDK calls."

  defstruct [
    :access_token,
    :plug,
    timeout: 60_000,
    max_retries: 3,
    custom_headers: %{},
    corporation_id: nil,
    integrator_id: nil,
    platform_id: nil
  ]

  @type t :: %__MODULE__{
          access_token: String.t(),
          plug: term() | nil,
          timeout: non_neg_integer(),
          max_retries: non_neg_integer(),
          custom_headers: map(),
          corporation_id: String.t() | nil,
          integrator_id: String.t() | nil,
          platform_id: String.t() | nil
        }
end
