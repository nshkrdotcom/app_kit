defmodule AppKit.OptimizationSurface.RunCreateRequest do
  @moduledoc "Optimization run creation request."
  @enforce_keys [
    :request_ref,
    :tenant_ref,
    :authority_ref,
    :actor_ref,
    :target_ref,
    :objective_refs,
    :model_profile_refs,
    :endpoint_profile_refs,
    :eval_suite_ref,
    :replay_bundle_ref,
    :budget_ref,
    :trace_refs,
    :idempotency_ref
  ]
  defstruct @enforce_keys
  @type t :: %__MODULE__{}
end

defmodule AppKit.OptimizationSurface.CandidateProjection do
  @moduledoc "Optimization candidate projection."
  @enforce_keys [
    :candidate_ref,
    :run_ref,
    :lineage_refs,
    :score_refs,
    :eval_refs,
    :replay_refs,
    :budget_refs,
    :trace_refs,
    :promotion_refs,
    :rollback_refs
  ]
  defstruct @enforce_keys
  @type t :: %__MODULE__{}
end

defmodule AppKit.OptimizationSurface.CandidateComparison do
  @moduledoc "Candidate comparison projection."
  @enforce_keys [
    :comparison_ref,
    :baseline_candidate_ref,
    :challenger_candidate_ref,
    :score_refs,
    :eval_refs,
    :replay_refs,
    :budget_refs,
    :trace_refs,
    :decision_ref
  ]
  defstruct @enforce_keys
  @type t :: %__MODULE__{}
end

defmodule AppKit.OptimizationSurface.RunControlRequest do
  @moduledoc "Pause, resume, or cancel request."
  @enforce_keys [:request_ref, :run_ref, :authority_ref, :actor_ref, :control_class, :trace_refs]
  defstruct @enforce_keys
  @type t :: %__MODULE__{}
end

defmodule AppKit.OptimizationSurface.PromotionDecisionProjection do
  @moduledoc "Promotion or rollback projection."
  @enforce_keys [
    :decision_class,
    :candidate_ref,
    :promotion_ref,
    :rollback_ref,
    :gate_refs,
    :provenance_ref,
    :trace_refs
  ]
  defstruct @enforce_keys
  @type t :: %__MODULE__{}
end

defmodule AppKit.OptimizationSurface.LineageProjection do
  @moduledoc "GEPA lineage projection."
  @enforce_keys [
    :run_ref,
    :candidate_refs,
    :lineage_refs,
    :eval_refs,
    :promotion_refs,
    :rollback_refs,
    :trace_refs
  ]
  defstruct @enforce_keys
  @type t :: %__MODULE__{}
end

defmodule AppKit.OptimizationSurface do
  @moduledoc """
  DTO-only GEPA optimization command and projection surface.
  """

  alias AppKit.OptimizationSurface.{
    CandidateComparison,
    CandidateProjection,
    LineageProjection,
    PromotionDecisionProjection,
    RunControlRequest,
    RunCreateRequest
  }

  @control_classes [:pause, :resume, :cancel]
  @promotion_gate_fields [
    :eval_ref,
    :replay_ref,
    :guardrail_ref,
    :cost_ref,
    :shadow_ref,
    :canary_ref,
    :human_approval_ref,
    :provenance_ref,
    :rollback_ref
  ]
  @raw_keys [
    :body,
    :model_output,
    :provider_payload,
    :raw_body,
    :raw_payload,
    :secret,
    :workflow_history,
    "body",
    "model_output",
    "provider_payload",
    "raw_body",
    "raw_payload",
    "secret",
    "workflow_history"
  ]

  @spec create_run_request(map()) :: {:ok, RunCreateRequest.t()} | {:error, term()}
  def create_run_request(attrs) when is_map(attrs) do
    with :ok <- reject_raw(attrs),
         :ok <-
           required_strings(attrs, [
             :request_ref,
             :tenant_ref,
             :authority_ref,
             :actor_ref,
             :target_ref,
             :eval_suite_ref,
             :replay_bundle_ref,
             :budget_ref,
             :idempotency_ref
           ]),
         {:ok, objective_refs} <- string_list(attrs, :objective_refs, []),
         {:ok, model_profile_refs} <- string_list(attrs, :model_profile_refs, []),
         {:ok, endpoint_profile_refs} <- string_list(attrs, :endpoint_profile_refs, []),
         {:ok, trace_refs} <- string_list(attrs, :trace_refs, []) do
      {:ok,
       %RunCreateRequest{
         request_ref: fetch!(attrs, :request_ref),
         tenant_ref: fetch!(attrs, :tenant_ref),
         authority_ref: fetch!(attrs, :authority_ref),
         actor_ref: fetch!(attrs, :actor_ref),
         target_ref: fetch!(attrs, :target_ref),
         objective_refs: objective_refs,
         model_profile_refs: model_profile_refs,
         endpoint_profile_refs: endpoint_profile_refs,
         eval_suite_ref: fetch!(attrs, :eval_suite_ref),
         replay_bundle_ref: fetch!(attrs, :replay_bundle_ref),
         budget_ref: fetch!(attrs, :budget_ref),
         trace_refs: trace_refs,
         idempotency_ref: fetch!(attrs, :idempotency_ref)
       }}
    end
  end

  def create_run_request(_attrs), do: {:error, :invalid_optimization_run_create_request}

  @spec candidate_projection(map()) :: {:ok, CandidateProjection.t()} | {:error, term()}
  def candidate_projection(attrs) when is_map(attrs) do
    with :ok <- reject_raw(attrs),
         :ok <- required_strings(attrs, [:candidate_ref, :run_ref]),
         {:ok, lineage_refs} <- string_list(attrs, :lineage_refs, []),
         {:ok, score_refs} <- string_list(attrs, :score_refs, []),
         {:ok, eval_refs} <- string_list(attrs, :eval_refs, []),
         {:ok, replay_refs} <- string_list(attrs, :replay_refs, []),
         {:ok, budget_refs} <- string_list(attrs, :budget_refs, []),
         {:ok, trace_refs} <- string_list(attrs, :trace_refs, []),
         {:ok, promotion_refs} <- string_list(attrs, :promotion_refs, []),
         {:ok, rollback_refs} <- string_list(attrs, :rollback_refs, []) do
      {:ok,
       %CandidateProjection{
         candidate_ref: fetch!(attrs, :candidate_ref),
         run_ref: fetch!(attrs, :run_ref),
         lineage_refs: lineage_refs,
         score_refs: score_refs,
         eval_refs: eval_refs,
         replay_refs: replay_refs,
         budget_refs: budget_refs,
         trace_refs: trace_refs,
         promotion_refs: promotion_refs,
         rollback_refs: rollback_refs
       }}
    end
  end

  def candidate_projection(_attrs), do: {:error, :invalid_candidate_projection}

  @spec compare_candidates(map()) :: {:ok, CandidateComparison.t()} | {:error, term()}
  def compare_candidates(attrs) when is_map(attrs) do
    with :ok <- reject_raw(attrs),
         :ok <-
           required_strings(attrs, [
             :comparison_ref,
             :baseline_candidate_ref,
             :challenger_candidate_ref,
             :decision_ref
           ]),
         {:ok, score_refs} <- string_list(attrs, :score_refs, []),
         {:ok, eval_refs} <- string_list(attrs, :eval_refs, []),
         {:ok, replay_refs} <- string_list(attrs, :replay_refs, []),
         {:ok, budget_refs} <- string_list(attrs, :budget_refs, []),
         {:ok, trace_refs} <- string_list(attrs, :trace_refs, []) do
      {:ok,
       %CandidateComparison{
         comparison_ref: fetch!(attrs, :comparison_ref),
         baseline_candidate_ref: fetch!(attrs, :baseline_candidate_ref),
         challenger_candidate_ref: fetch!(attrs, :challenger_candidate_ref),
         score_refs: score_refs,
         eval_refs: eval_refs,
         replay_refs: replay_refs,
         budget_refs: budget_refs,
         trace_refs: trace_refs,
         decision_ref: fetch!(attrs, :decision_ref)
       }}
    end
  end

  def compare_candidates(_attrs), do: {:error, :invalid_candidate_comparison}

  @spec control_run(map()) :: {:ok, RunControlRequest.t()} | {:error, term()}
  def control_run(attrs) when is_map(attrs) do
    with :ok <- reject_raw(attrs),
         :ok <- required_strings(attrs, [:request_ref, :run_ref, :authority_ref, :actor_ref]),
         {:ok, control_class} <- control_class(attrs),
         {:ok, trace_refs} <- string_list(attrs, :trace_refs, []) do
      {:ok,
       %RunControlRequest{
         request_ref: fetch!(attrs, :request_ref),
         run_ref: fetch!(attrs, :run_ref),
         authority_ref: fetch!(attrs, :authority_ref),
         actor_ref: fetch!(attrs, :actor_ref),
         control_class: control_class,
         trace_refs: trace_refs
       }}
    end
  end

  def control_run(_attrs), do: {:error, :invalid_optimization_control_request}

  @spec promote_candidate(map()) :: {:ok, PromotionDecisionProjection.t()} | {:error, term()}
  def promote_candidate(attrs) when is_map(attrs) do
    missing = missing_fields(attrs, @promotion_gate_fields)

    with :ok <- reject_raw(attrs),
         [] <- missing,
         :ok <-
           required_strings(attrs, [
             :request_ref,
             :candidate_ref,
             :operator_ref,
             :promotion_ref
           ]),
         {:ok, trace_refs} <- string_list(attrs, :trace_refs, []) do
      {:ok,
       %PromotionDecisionProjection{
         decision_class: :promote,
         candidate_ref: fetch!(attrs, :candidate_ref),
         promotion_ref: fetch!(attrs, :promotion_ref),
         rollback_ref: fetch!(attrs, :rollback_ref),
         gate_refs: Enum.map(@promotion_gate_fields, &fetch!(attrs, &1)),
         provenance_ref: fetch!(attrs, :provenance_ref),
         trace_refs: trace_refs
       }}
    else
      [_ | _] = fields -> {:error, {:missing_promotion_gate_refs, fields}}
      error -> error
    end
  end

  def promote_candidate(_attrs), do: {:error, :invalid_promotion_request}

  @spec rollback_candidate(map()) :: {:ok, PromotionDecisionProjection.t()} | {:error, term()}
  def rollback_candidate(attrs) when is_map(attrs) do
    with :ok <- reject_raw(attrs),
         :ok <-
           required_strings(attrs, [
             :candidate_ref,
             :rollback_ref,
             :provenance_ref
           ]),
         {:ok, trace_refs} <- string_list(attrs, :trace_refs, []) do
      {:ok,
       %PromotionDecisionProjection{
         decision_class: :rollback,
         candidate_ref: fetch!(attrs, :candidate_ref),
         promotion_ref: fetch(attrs, :promotion_ref),
         rollback_ref: fetch!(attrs, :rollback_ref),
         gate_refs: [],
         provenance_ref: fetch!(attrs, :provenance_ref),
         trace_refs: trace_refs
       }}
    end
  end

  def rollback_candidate(_attrs), do: {:error, :invalid_rollback_request}

  @spec lineage_projection(map()) :: {:ok, LineageProjection.t()} | {:error, term()}
  def lineage_projection(attrs) when is_map(attrs) do
    with :ok <- reject_raw(attrs),
         :ok <- required_strings(attrs, [:run_ref]),
         {:ok, candidate_refs} <- string_list(attrs, :candidate_refs, []),
         {:ok, lineage_refs} <- string_list(attrs, :lineage_refs, []),
         {:ok, eval_refs} <- string_list(attrs, :eval_refs, []),
         {:ok, promotion_refs} <- string_list(attrs, :promotion_refs, []),
         {:ok, rollback_refs} <- string_list(attrs, :rollback_refs, []),
         {:ok, trace_refs} <- string_list(attrs, :trace_refs, []) do
      {:ok,
       %LineageProjection{
         run_ref: fetch!(attrs, :run_ref),
         candidate_refs: candidate_refs,
         lineage_refs: lineage_refs,
         eval_refs: eval_refs,
         promotion_refs: promotion_refs,
         rollback_refs: rollback_refs,
         trace_refs: trace_refs
       }}
    end
  end

  def lineage_projection(_attrs), do: {:error, :invalid_lineage_projection}

  defp control_class(attrs) do
    value = fetch(attrs, :control_class)
    if value in @control_classes, do: {:ok, value}, else: {:error, :invalid_control_class}
  end

  defp required_strings(attrs, fields) do
    case Enum.find(fields, &(present_string?(fetch(attrs, &1)) == false)) do
      nil -> :ok
      field -> {:error, {:missing_required_ref, field}}
    end
  end

  defp missing_fields(attrs, fields) do
    Enum.reject(fields, &present_string?(fetch(attrs, &1)))
  end

  defp string_list(attrs, field, default) do
    values = fetch(attrs, field, default)

    if is_list(values) and Enum.all?(values, &present_string?/1) do
      {:ok, values}
    else
      {:error, {:invalid_ref_list, field}}
    end
  end

  defp reject_raw(value) do
    case raw_key(value) do
      nil -> :ok
      key -> {:error, {:raw_optimization_surface_payload_forbidden, key}}
    end
  end

  defp raw_key(%_struct{} = value), do: value |> Map.from_struct() |> raw_key()

  defp raw_key(value) when is_map(value) do
    Enum.find_value(value, fn {key, nested} ->
      if key in @raw_keys, do: key, else: raw_key(nested)
    end)
  end

  defp raw_key(value) when is_list(value), do: Enum.find_value(value, &raw_key/1)
  defp raw_key(_value), do: nil

  defp fetch!(attrs, field), do: fetch(attrs, field)

  defp fetch(attrs, field, default \\ nil) do
    string_field = Atom.to_string(field)

    cond do
      Map.has_key?(attrs, field) -> Map.fetch!(attrs, field)
      Map.has_key?(attrs, string_field) -> Map.fetch!(attrs, string_field)
      true -> default
    end
  end

  defp present_string?(value), do: is_binary(value) and String.trim(value) != ""
end
