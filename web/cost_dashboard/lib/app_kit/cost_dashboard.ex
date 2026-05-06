defmodule AppKit.CostDashboard do
  @moduledoc """
  Cost and budget dashboard render contracts.
  """

  alias AppKit.Web.Components

  defmodule Dashboard do
    @moduledoc "Cost dashboard render state."
    @type t :: %__MODULE__{
            dashboard_ref: String.t(),
            tenant_ref: String.t(),
            threshold_policy_ref: String.t(),
            cost_rows: [map()],
            budget_rows: [map()],
            redaction_posture: String.t()
          }

    @enforce_keys [
      :dashboard_ref,
      :tenant_ref,
      :threshold_policy_ref,
      :cost_rows,
      :budget_rows,
      :redaction_posture
    ]
    defstruct @enforce_keys
  end

  @raw_keys [
    :amount,
    :amount_native,
    :cost_amount,
    :raw_amount,
    :provider_account_id,
    :provider_payload,
    :authorization_header,
    :token,
    :secret,
    "amount",
    "amount_native",
    "cost_amount",
    "raw_amount",
    "provider_account_id",
    "provider_payload",
    "authorization_header",
    "token",
    "secret"
  ]

  @spec dashboard(map()) :: {:ok, Dashboard.t()} | {:error, term()}
  def dashboard(attrs) when is_map(attrs) do
    with :ok <- reject_raw(attrs),
         :ok <- Components.reject_raw_assigns(attrs),
         {:ok, dashboard_ref} <- required_string(attrs, :dashboard_ref),
         {:ok, tenant_ref} <- required_string(attrs, :tenant_ref),
         {:ok, threshold_policy_ref} <- required_string(attrs, :threshold_policy_ref),
         {:ok, cost_rows} <- rows(attrs, :cost_rows),
         {:ok, budget_rows} <- rows(attrs, :budget_rows) do
      {:ok,
       %Dashboard{
         dashboard_ref: dashboard_ref,
         tenant_ref: tenant_ref,
         threshold_policy_ref: threshold_policy_ref,
         cost_rows: redact_provider_accounts(cost_rows),
         budget_rows: budget_rows,
         redaction_posture: "amount_classes_and_refs_only"
       }}
    end
  end

  def dashboard(_attrs), do: {:error, :invalid_cost_dashboard_attrs}

  defp rows(attrs, field) do
    values = fetch(attrs, field, [])

    if is_list(values) and Enum.all?(values, &is_map/1) do
      {:ok, values}
    else
      {:error, {:invalid_cost_dashboard_rows, field}}
    end
  end

  defp redact_provider_accounts(rows) do
    Enum.map(rows, fn row ->
      row
      |> Map.delete(:provider_account_ref)
      |> Map.delete("provider_account_ref")
      |> Map.put(:provider_account_ref, "provider-account://redacted")
    end)
  end

  defp reject_raw(attrs) do
    case Enum.find(@raw_keys, &Map.has_key?(attrs, &1)) do
      nil -> :ok
      key -> {:error, {:raw_cost_dashboard_payload_forbidden, key}}
    end
  end

  defp required_string(attrs, field) do
    case fetch(attrs, field) do
      value when is_binary(value) and value != "" -> {:ok, value}
      _value -> {:error, {:missing_cost_dashboard_ref, field}}
    end
  end

  defp fetch(attrs, field), do: fetch(attrs, field, nil)

  defp fetch(attrs, field, default),
    do: Map.get(attrs, field) || Map.get(attrs, Atom.to_string(field), default)
end
