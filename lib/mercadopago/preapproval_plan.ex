defmodule Mercadopago.PreapprovalPlan do
  @moduledoc "Subscription plan template management."

  @behaviour Mercadopago.Resource

  alias Mercadopago.{Client, HTTP}

  @doc "Searches preapproval plans matching `filters` (query-string parameters)."
  @spec search(Client.t(), map() | nil, keyword()) :: HTTP.response()
  def search(%Client{} = client, filters \\ nil, opts \\ []) do
    HTTP.get(client, "/preapproval_plan/search", filters, opts)
  end

  @doc "Fetches a preapproval plan by id."
  @spec get(Client.t(), String.t(), keyword()) :: HTTP.response()
  def get(%Client{} = client, preapproval_plan_id, opts \\ []) do
    HTTP.get(client, "/preapproval_plan/#{preapproval_plan_id}", nil, opts)
  end

  @doc "Creates a preapproval plan from `preapproval_plan_data`."
  @spec create(Client.t(), map(), keyword()) :: HTTP.response()
  def create(%Client{} = client, preapproval_plan_data, opts \\ []) do
    HTTP.post(client, "/preapproval_plan/", preapproval_plan_data, opts)
  end

  @doc "Updates a preapproval plan."
  @spec update(Client.t(), String.t(), map(), keyword()) :: HTTP.response()
  def update(%Client{} = client, preapproval_plan_id, preapproval_plan_data, opts \\ []) do
    HTTP.put(client, "/preapproval_plan/#{preapproval_plan_id}", preapproval_plan_data, opts)
  end
end
