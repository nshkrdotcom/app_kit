defmodule AppKit.BudgetSurface do
  @moduledoc """
  DTO-only budget surface for operator workflows.
  """

  defmodule BudgetSetRequest do
    @moduledoc "Budget set request."
    @enforce_keys [:request_ref, :tenant_ref, :authority_ref, :installation_ref, :budget_ref]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            request_ref: String.t(),
            tenant_ref: String.t(),
            authority_ref: String.t(),
            installation_ref: String.t(),
            budget_ref: String.t()
          }
  end

  defmodule BudgetViewProjection do
    @moduledoc "Budget view projection."
    @enforce_keys [:budget_ref, :period_class, :hard_cap_class, :soft_cap_class, :decision_class]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            budget_ref: String.t(),
            period_class: atom(),
            hard_cap_class: atom(),
            soft_cap_class: atom(),
            decision_class: atom()
          }
  end

  defmodule BudgetExhaustionRecord do
    @moduledoc "Budget exhaustion projection."
    @enforce_keys [:budget_ref, :locus, :decision_class, :requested_units, :granted_units]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            budget_ref: String.t(),
            locus: atom(),
            decision_class: atom(),
            requested_units: non_neg_integer(),
            granted_units: non_neg_integer()
          }
  end

  defmodule BudgetOverrideRequest do
    @moduledoc "Budget override request."
    @enforce_keys [
      :request_ref,
      :budget_ref,
      :operator_ref,
      :permission_ref,
      :reason_ref,
      :duration_seconds
    ]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            request_ref: String.t(),
            budget_ref: String.t(),
            operator_ref: String.t(),
            permission_ref: String.t(),
            reason_ref: String.t(),
            duration_seconds: pos_integer()
          }
  end

  defmodule BudgetAuditProjection do
    @moduledoc "Budget audit projection."
    @enforce_keys [:audit_ref, :budget_ref, :decision_refs, :redaction_posture]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            audit_ref: String.t(),
            budget_ref: String.t(),
            decision_refs: [String.t()],
            redaction_posture: String.t()
          }
  end

  @period_classes [:per_run, :per_skill, :per_day, :per_tenant, :per_authority]
  @decision_classes [
    :allow,
    :allow_warn_soft,
    :deny_hard_exhausted,
    :deny_policy,
    :deny_revoked,
    :allow_with_override
  ]
  @loci [:preflight, :append, :stream, :runtime_admission, :reconciliation]
  @cap_classes [:redacted_below_floor, :redacted_above_ceiling, :bounded_excerpt]
  @raw_keys [
    :amount,
    :budget_amount,
    :raw_amount,
    :provider_payload,
    :override_reason,
    "amount",
    "budget_amount",
    "raw_amount",
    "provider_payload",
    "override_reason"
  ]

  @spec set_request(map()) :: {:ok, BudgetSetRequest.t()} | {:error, term()}
  def set_request(attrs) when is_map(attrs) do
    with :ok <- reject_raw(attrs),
         :ok <-
           required_strings(attrs, [
             :request_ref,
             :tenant_ref,
             :authority_ref,
             :installation_ref,
             :budget_ref
           ]) do
      {:ok,
       %BudgetSetRequest{
         request_ref: fetch!(attrs, :request_ref),
         tenant_ref: fetch!(attrs, :tenant_ref),
         authority_ref: fetch!(attrs, :authority_ref),
         installation_ref: fetch!(attrs, :installation_ref),
         budget_ref: fetch!(attrs, :budget_ref)
       }}
    end
  end

  def set_request(_attrs), do: {:error, :invalid_budget_set_request}

  @spec view_projection(map()) :: {:ok, BudgetViewProjection.t()} | {:error, term()}
  def view_projection(attrs) when is_map(attrs) do
    with :ok <- reject_raw(attrs),
         :ok <- required_strings(attrs, [:budget_ref]),
         {:ok, period_class} <- member(attrs, :period_class, @period_classes),
         {:ok, hard_cap_class} <- member(attrs, :hard_cap_class, @cap_classes),
         {:ok, soft_cap_class} <- member(attrs, :soft_cap_class, @cap_classes),
         {:ok, decision_class} <- member(attrs, :decision_class, @decision_classes) do
      {:ok,
       %BudgetViewProjection{
         budget_ref: fetch!(attrs, :budget_ref),
         period_class: period_class,
         hard_cap_class: hard_cap_class,
         soft_cap_class: soft_cap_class,
         decision_class: decision_class
       }}
    end
  end

  def view_projection(_attrs), do: {:error, :invalid_budget_view_projection}

  @spec exhaustion_record(map()) :: {:ok, BudgetExhaustionRecord.t()} | {:error, term()}
  def exhaustion_record(attrs) when is_map(attrs) do
    with :ok <- reject_raw(attrs),
         :ok <- required_strings(attrs, [:budget_ref]),
         {:ok, locus} <- member(attrs, :locus, @loci),
         {:ok, decision_class} <- member(attrs, :decision_class, @decision_classes),
         {:ok, requested_units} <- non_negative_integer(attrs, :requested_units),
         {:ok, granted_units} <- non_negative_integer(attrs, :granted_units) do
      {:ok,
       %BudgetExhaustionRecord{
         budget_ref: fetch!(attrs, :budget_ref),
         locus: locus,
         decision_class: decision_class,
         requested_units: requested_units,
         granted_units: granted_units
       }}
    end
  end

  def exhaustion_record(_attrs), do: {:error, :invalid_budget_exhaustion_record}

  @spec override_request(map()) :: {:ok, BudgetOverrideRequest.t()} | {:error, term()}
  def override_request(attrs) when is_map(attrs) do
    with :ok <- reject_raw(attrs),
         :ok <-
           required_strings(attrs, [
             :request_ref,
             :budget_ref,
             :operator_ref,
             :permission_ref,
             :reason_ref
           ]),
         {:ok, duration_seconds} <- positive_integer(attrs, :duration_seconds),
         :ok <- bounded_duration(duration_seconds) do
      {:ok,
       %BudgetOverrideRequest{
         request_ref: fetch!(attrs, :request_ref),
         budget_ref: fetch!(attrs, :budget_ref),
         operator_ref: fetch!(attrs, :operator_ref),
         permission_ref: fetch!(attrs, :permission_ref),
         reason_ref: fetch!(attrs, :reason_ref),
         duration_seconds: duration_seconds
       }}
    end
  end

  def override_request(_attrs), do: {:error, :invalid_budget_override_request}

  @spec audit_projection(map()) :: {:ok, BudgetAuditProjection.t()} | {:error, term()}
  def audit_projection(attrs) when is_map(attrs) do
    with :ok <- reject_raw(attrs),
         :ok <- required_strings(attrs, [:audit_ref, :budget_ref]),
         {:ok, decision_refs} <- string_list(attrs, :decision_refs, []) do
      {:ok,
       %BudgetAuditProjection{
         audit_ref: fetch!(attrs, :audit_ref),
         budget_ref: fetch!(attrs, :budget_ref),
         decision_refs: decision_refs,
         redaction_posture: "bounded_refs_only"
       }}
    end
  end

  def audit_projection(_attrs), do: {:error, :invalid_budget_audit_projection}

  defp string_list(attrs, field, default) do
    values = fetch(attrs, field, default)

    if is_list(values) and Enum.all?(values, &present_string?/1) do
      {:ok, values}
    else
      {:error, {:invalid_budget_surface_ref, field}}
    end
  end

  defp required_strings(attrs, fields) do
    case Enum.find(fields, &(not present_string?(fetch(attrs, &1)))) do
      nil -> :ok
      field -> {:error, {:missing_budget_surface_ref, field}}
    end
  end

  defp member(attrs, field, allowed) do
    case fetch(attrs, field) do
      value when is_atom(value) -> member_atom(value, allowed, field)
      value when is_binary(value) -> member_string(value, allowed, field)
      _value -> {:error, {:unknown_budget_surface_enum, field}}
    end
  end

  defp member_atom(value, allowed, field) do
    if value in allowed do
      {:ok, value}
    else
      {:error, {:unknown_budget_surface_enum, field}}
    end
  end

  defp member_string(value, allowed, field) do
    case Enum.find(allowed, &(Atom.to_string(&1) == value)) do
      nil -> {:error, {:unknown_budget_surface_enum, field}}
      found -> {:ok, found}
    end
  end

  defp non_negative_integer(attrs, field) do
    case fetch(attrs, field) do
      value when is_integer(value) and value >= 0 -> {:ok, value}
      _value -> {:error, {:invalid_budget_surface_units, field}}
    end
  end

  defp positive_integer(attrs, field) do
    case fetch(attrs, field) do
      value when is_integer(value) and value > 0 -> {:ok, value}
      _value -> {:error, {:invalid_budget_surface_units, field}}
    end
  end

  defp bounded_duration(duration_seconds) do
    if duration_seconds <= 3_600, do: :ok, else: {:error, :budget_override_duration_unbounded}
  end

  defp reject_raw(attrs) do
    case Enum.find(@raw_keys, &Map.has_key?(attrs, &1)) do
      nil -> :ok
      key -> {:error, {:raw_budget_surface_payload_forbidden, key}}
    end
  end

  defp present_string?(value), do: is_binary(value) and String.trim(value) != ""
  defp fetch!(attrs, field), do: fetch(attrs, field)
  defp fetch(attrs, field), do: fetch(attrs, field, nil)

  defp fetch(attrs, field, default),
    do: Map.get(attrs, field) || Map.get(attrs, Atom.to_string(field), default)
end
