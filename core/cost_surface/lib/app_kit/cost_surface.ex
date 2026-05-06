defmodule AppKit.CostSurface do
  @moduledoc """
  DTO-only cost surface with bounded amount classes.
  """

  defmodule CostBreakdownRequest do
    @moduledoc "Operator cost breakdown request."
    @enforce_keys [:request_ref, :tenant_ref, :authority_ref, :installation_ref, :group_by]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            request_ref: String.t(),
            tenant_ref: String.t(),
            authority_ref: String.t(),
            installation_ref: String.t(),
            group_by: atom()
          }
  end

  defmodule CostFactProjection do
    @moduledoc "Redacted cost fact projection."
    @enforce_keys [
      :fact_ref,
      :run_ref,
      :capability_id,
      :cost_class,
      :amount_class,
      :token_meter_ref,
      :trace_id
    ]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            fact_ref: String.t(),
            run_ref: String.t(),
            capability_id: String.t(),
            cost_class: atom(),
            amount_class: atom(),
            token_meter_ref: String.t(),
            trace_id: String.t()
          }
  end

  defmodule CostBreakdownProjection do
    @moduledoc "Operator-facing bounded cost breakdown."
    @enforce_keys [:projection_ref, :tenant_ref, :group_by, :facts, :redaction_posture]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            projection_ref: String.t(),
            tenant_ref: String.t(),
            group_by: atom(),
            facts: [CostFactProjection.t()],
            redaction_posture: String.t()
          }
  end

  defmodule CostExportRequest do
    @moduledoc "Bounded export request."
    @enforce_keys [:request_ref, :tenant_ref, :authority_ref, :installation_ref, :projection_ref]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            request_ref: String.t(),
            tenant_ref: String.t(),
            authority_ref: String.t(),
            installation_ref: String.t(),
            projection_ref: String.t()
          }
  end

  @cost_classes [:production, :replay, :eval, :simulation, :infrastructure]
  @amount_classes [
    :production_native,
    :redacted_below_floor,
    :redacted_above_ceiling,
    :bounded_excerpt
  ]
  @group_by [
    :tenant_ref,
    :run_ref,
    :connector_instance_ref,
    :provider_account_ref,
    :model_ref,
    :capability_id,
    :cost_class
  ]
  @raw_keys [
    :amount,
    :amount_native,
    :cost_amount,
    :raw_amount,
    :provider_payload,
    :body,
    :raw_body,
    "amount",
    "amount_native",
    "cost_amount",
    "raw_amount",
    "provider_payload",
    "body",
    "raw_body"
  ]

  @spec breakdown_request(map()) :: {:ok, CostBreakdownRequest.t()} | {:error, term()}
  def breakdown_request(attrs) when is_map(attrs) do
    with :ok <- reject_raw(attrs),
         :ok <-
           required_strings(attrs, [:request_ref, :tenant_ref, :authority_ref, :installation_ref]),
         {:ok, group_by} <- member(attrs, :group_by, @group_by) do
      {:ok,
       %CostBreakdownRequest{
         request_ref: fetch!(attrs, :request_ref),
         tenant_ref: fetch!(attrs, :tenant_ref),
         authority_ref: fetch!(attrs, :authority_ref),
         installation_ref: fetch!(attrs, :installation_ref),
         group_by: group_by
       }}
    end
  end

  def breakdown_request(_attrs), do: {:error, :invalid_cost_breakdown_request}

  @spec fact_projection(map()) :: {:ok, CostFactProjection.t()} | {:error, term()}
  def fact_projection(attrs) when is_map(attrs) do
    with :ok <- reject_raw(attrs),
         :ok <-
           required_strings(attrs, [
             :fact_ref,
             :run_ref,
             :capability_id,
             :token_meter_ref,
             :trace_id
           ]),
         {:ok, cost_class} <- member(attrs, :cost_class, @cost_classes),
         {:ok, amount_class} <- member(attrs, :amount_class, @amount_classes) do
      {:ok,
       %CostFactProjection{
         fact_ref: fetch!(attrs, :fact_ref),
         run_ref: fetch!(attrs, :run_ref),
         capability_id: fetch!(attrs, :capability_id),
         cost_class: cost_class,
         amount_class: amount_class,
         token_meter_ref: fetch!(attrs, :token_meter_ref),
         trace_id: fetch!(attrs, :trace_id)
       }}
    end
  end

  def fact_projection(_attrs), do: {:error, :invalid_cost_fact_projection}

  @spec breakdown_projection(map()) :: {:ok, CostBreakdownProjection.t()} | {:error, term()}
  def breakdown_projection(attrs) when is_map(attrs) do
    with :ok <- reject_raw(attrs),
         :ok <- required_strings(attrs, [:projection_ref, :tenant_ref]),
         {:ok, group_by} <- member(attrs, :group_by, @group_by),
         {:ok, facts} <- fact_list(fetch(attrs, :facts, [])) do
      {:ok,
       %CostBreakdownProjection{
         projection_ref: fetch!(attrs, :projection_ref),
         tenant_ref: fetch!(attrs, :tenant_ref),
         group_by: group_by,
         facts: facts,
         redaction_posture: "bounded_amount_classes_only"
       }}
    end
  end

  def breakdown_projection(_attrs), do: {:error, :invalid_cost_breakdown_projection}

  @spec export_request(map()) :: {:ok, CostExportRequest.t()} | {:error, term()}
  def export_request(attrs) when is_map(attrs) do
    with :ok <- reject_raw(attrs),
         :ok <-
           required_strings(attrs, [
             :request_ref,
             :tenant_ref,
             :authority_ref,
             :installation_ref,
             :projection_ref
           ]) do
      {:ok,
       %CostExportRequest{
         request_ref: fetch!(attrs, :request_ref),
         tenant_ref: fetch!(attrs, :tenant_ref),
         authority_ref: fetch!(attrs, :authority_ref),
         installation_ref: fetch!(attrs, :installation_ref),
         projection_ref: fetch!(attrs, :projection_ref)
       }}
    end
  end

  def export_request(_attrs), do: {:error, :invalid_cost_export_request}

  defp fact_list(values) when is_list(values) do
    Enum.reduce_while(values, {:ok, []}, fn attrs, {:ok, acc} ->
      case fact_projection(attrs) do
        {:ok, projection} -> {:cont, {:ok, [projection | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, projections} -> {:ok, Enum.reverse(projections)}
      error -> error
    end
  end

  defp fact_list(_values), do: {:error, :invalid_cost_fact_projection_list}

  defp required_strings(attrs, fields) do
    case Enum.find(fields, &(not present_string?(fetch(attrs, &1)))) do
      nil -> :ok
      field -> {:error, {:missing_cost_surface_ref, field}}
    end
  end

  defp member(attrs, field, allowed) do
    case fetch(attrs, field) do
      value when is_atom(value) -> member_atom(value, allowed, field)
      value when is_binary(value) -> member_string(value, allowed, field)
      _value -> {:error, {:unknown_cost_surface_enum, field}}
    end
  end

  defp member_atom(value, allowed, field) do
    if value in allowed do
      {:ok, value}
    else
      {:error, {:unknown_cost_surface_enum, field}}
    end
  end

  defp member_string(value, allowed, field) do
    case Enum.find(allowed, &(Atom.to_string(&1) == value)) do
      nil -> {:error, {:unknown_cost_surface_enum, field}}
      found -> {:ok, found}
    end
  end

  defp reject_raw(attrs) do
    case Enum.find(@raw_keys, &Map.has_key?(attrs, &1)) do
      nil -> :ok
      key -> {:error, {:raw_cost_surface_payload_forbidden, key}}
    end
  end

  defp present_string?(value), do: is_binary(value) and String.trim(value) != ""
  defp fetch!(attrs, field), do: fetch(attrs, field)
  defp fetch(attrs, field), do: fetch(attrs, field, nil)

  defp fetch(attrs, field, default),
    do: Map.get(attrs, field) || Map.get(attrs, Atom.to_string(field), default)
end
