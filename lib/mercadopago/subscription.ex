defmodule Mercadopago.Subscription do
  @moduledoc """
  Plan-based recurring subscriptions.

  These are the same `/preapproval` endpoints `Mercadopago.Preapproval` exposes;
  this module exists so the name matches the reference Ruby SDK, where
  `sdk.subscription` was added in 3.3.0 alongside `sdk.preapproval`. Every
  function here delegates — pick whichever name reads better at the call site.

  A subscription ties a payer to a `Mercadopago.PreapprovalPlan`, so `create/3`
  expects a `preapproval_plan_id` in the body.
  """

  alias Mercadopago.Preapproval

  @doc "Searches subscriptions matching `filters` (query-string parameters)."
  defdelegate search(client, filters \\ nil, opts \\ []), to: Preapproval

  @doc "Streams every result of `search/3`. See `Mercadopago.Pagination.stream/3`."
  defdelegate search_stream(client, filters \\ nil, opts \\ []), to: Preapproval

  @doc "Fetches a subscription by id."
  defdelegate get(client, subscription_id, opts \\ []), to: Preapproval

  @doc "Creates a subscription from `subscription_data`."
  defdelegate create(client, subscription_data, opts \\ []), to: Preapproval

  @doc "Updates a subscription (e.g. to pause, resume or cancel it)."
  defdelegate update(client, subscription_id, subscription_data, opts \\ []), to: Preapproval
end
