defmodule AppKit.EvalSurface do
  @moduledoc """
  DTO-only eval surface.
  """

  @verdicts [:pass, :regress, :improve, :inconclusive]
  @raw_keys [
    :body,
    :raw_body,
    :payload,
    :raw_payload,
    :expected_output,
    :model_output,
    "body",
    "raw_body",
    "payload",
    "raw_payload",
    "expected_output",
    "model_output"
  ]

  defmodule EvalSuiteAuthorRequest do
    @moduledoc "Eval suite authoring DTO."
    @enforce_keys [:request_ref, :suite_ref, :tenant_ref, :authority_ref, :installation_ref]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            request_ref: String.t(),
            suite_ref: String.t(),
            tenant_ref: String.t(),
            authority_ref: String.t(),
            installation_ref: String.t()
          }
  end

  defmodule EvalRunRequest do
    @moduledoc "Eval run request DTO."
    @enforce_keys [:request_ref, :suite_ref, :variant_matrix_ref, :trace_ref]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            request_ref: String.t(),
            suite_ref: String.t(),
            variant_matrix_ref: String.t(),
            trace_ref: String.t()
          }
  end

  defmodule EvalRunProjection do
    @moduledoc "Eval run projection DTO."
    @enforce_keys [:eval_run_ref, :suite_ref, :verdict, :case_projection_refs]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            eval_run_ref: String.t(),
            suite_ref: String.t(),
            verdict: atom(),
            case_projection_refs: [String.t()]
          }
  end

  defmodule EvalCaseProjection do
    @moduledoc "Eval case projection DTO."
    @enforce_keys [:case_ref, :verdict, :evidence_ref]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            case_ref: String.t(),
            verdict: atom(),
            evidence_ref: String.t()
          }
  end

  defmodule EvalVerdictProjection do
    @moduledoc "Eval verdict projection DTO."
    @enforce_keys [:verdict, :severity_class, :decision_evidence_ref]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            verdict: atom(),
            severity_class: String.t(),
            decision_evidence_ref: String.t()
          }
  end

  defmodule EvalPromoteRequest do
    @moduledoc "Eval-gated promotion DTO."
    @enforce_keys [
      :request_ref,
      :prompt_ref,
      :eval_run_ref,
      :guard_chain_ref,
      :decision_evidence_ref
    ]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            request_ref: String.t(),
            prompt_ref: String.t(),
            eval_run_ref: String.t(),
            guard_chain_ref: String.t(),
            decision_evidence_ref: String.t()
          }
  end

  @spec suite_author_request(map()) :: {:ok, EvalSuiteAuthorRequest.t()} | {:error, term()}
  def suite_author_request(attrs) when is_map(attrs) do
    with :ok <- reject_raw(attrs),
         :ok <-
           required_strings(attrs, [
             :request_ref,
             :suite_ref,
             :tenant_ref,
             :authority_ref,
             :installation_ref
           ]) do
      {:ok,
       %EvalSuiteAuthorRequest{
         request_ref: fetch!(attrs, :request_ref),
         suite_ref: fetch!(attrs, :suite_ref),
         tenant_ref: fetch!(attrs, :tenant_ref),
         authority_ref: fetch!(attrs, :authority_ref),
         installation_ref: fetch!(attrs, :installation_ref)
       }}
    end
  end

  @spec run_request(map()) :: {:ok, EvalRunRequest.t()} | {:error, term()}
  def run_request(attrs) when is_map(attrs) do
    with :ok <- reject_raw(attrs),
         :ok <-
           required_strings(attrs, [:request_ref, :suite_ref, :variant_matrix_ref, :trace_ref]) do
      {:ok,
       %EvalRunRequest{
         request_ref: fetch!(attrs, :request_ref),
         suite_ref: fetch!(attrs, :suite_ref),
         variant_matrix_ref: fetch!(attrs, :variant_matrix_ref),
         trace_ref: fetch!(attrs, :trace_ref)
       }}
    end
  end

  @spec run_projection(map()) :: {:ok, EvalRunProjection.t()} | {:error, term()}
  def run_projection(attrs) when is_map(attrs) do
    with :ok <- reject_raw(attrs),
         :ok <- required_strings(attrs, [:eval_run_ref, :suite_ref]),
         {:ok, verdict} <- verdict(attrs),
         {:ok, refs} <- string_list(attrs, :case_projection_refs, []) do
      {:ok,
       %EvalRunProjection{
         eval_run_ref: fetch!(attrs, :eval_run_ref),
         suite_ref: fetch!(attrs, :suite_ref),
         verdict: verdict,
         case_projection_refs: refs
       }}
    end
  end

  @spec case_projection(map()) :: {:ok, EvalCaseProjection.t()} | {:error, term()}
  def case_projection(attrs) when is_map(attrs) do
    with :ok <- reject_raw(attrs),
         :ok <- required_strings(attrs, [:case_ref, :evidence_ref]),
         {:ok, verdict} <- verdict(attrs) do
      {:ok,
       %EvalCaseProjection{
         case_ref: fetch!(attrs, :case_ref),
         verdict: verdict,
         evidence_ref: fetch!(attrs, :evidence_ref)
       }}
    end
  end

  @spec verdict_projection(map()) :: {:ok, EvalVerdictProjection.t()} | {:error, term()}
  def verdict_projection(attrs) when is_map(attrs) do
    with :ok <- reject_raw(attrs),
         :ok <- required_strings(attrs, [:severity_class, :decision_evidence_ref]),
         {:ok, verdict} <- verdict(attrs) do
      {:ok,
       %EvalVerdictProjection{
         verdict: verdict,
         severity_class: fetch!(attrs, :severity_class),
         decision_evidence_ref: fetch!(attrs, :decision_evidence_ref)
       }}
    end
  end

  @spec promote_request(map()) :: {:ok, EvalPromoteRequest.t()} | {:error, term()}
  def promote_request(attrs) when is_map(attrs) do
    with :ok <- reject_raw(attrs),
         :ok <-
           required_strings(attrs, [
             :request_ref,
             :prompt_ref,
             :eval_run_ref,
             :guard_chain_ref,
             :decision_evidence_ref
           ]) do
      {:ok,
       %EvalPromoteRequest{
         request_ref: fetch!(attrs, :request_ref),
         prompt_ref: fetch!(attrs, :prompt_ref),
         eval_run_ref: fetch!(attrs, :eval_run_ref),
         guard_chain_ref: fetch!(attrs, :guard_chain_ref),
         decision_evidence_ref: fetch!(attrs, :decision_evidence_ref)
       }}
    end
  end

  defp verdict(attrs) do
    value = fetch(attrs, :verdict)
    if value in @verdicts, do: {:ok, value}, else: {:error, :unknown_eval_verdict}
  end

  defp string_list(attrs, field, default) do
    values = fetch(attrs, field, default)

    if is_list(values) and Enum.all?(values, &present_string?/1) do
      {:ok, values}
    else
      {:error, {:invalid_eval_surface_ref, field}}
    end
  end

  defp reject_raw(attrs) do
    case Enum.find(@raw_keys, &Map.has_key?(attrs, &1)) do
      nil -> :ok
      key -> {:error, {:raw_eval_surface_payload_forbidden, key}}
    end
  end

  defp required_strings(attrs, fields) do
    case Enum.find(fields, &(not present_string?(fetch(attrs, &1)))) do
      nil -> :ok
      field -> {:error, {:missing_eval_surface_ref, field}}
    end
  end

  defp present_string?(value) when is_binary(value), do: String.trim(value) != ""
  defp present_string?(_value), do: false
  defp fetch!(attrs, field), do: fetch(attrs, field)
  defp fetch(attrs, field), do: fetch(attrs, field, nil)

  defp fetch(attrs, field, default),
    do: Map.get(attrs, field) || Map.get(attrs, Atom.to_string(field)) || default
end
