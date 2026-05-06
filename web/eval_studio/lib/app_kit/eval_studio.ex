defmodule AppKit.EvalStudio do
  @moduledoc """
  Eval studio render contracts.
  """

  alias AppKit.Web.Components

  defmodule Studio do
    @moduledoc "Eval studio render state."
    @type t :: %__MODULE__{
            studio_ref: String.t(),
            tenant_ref: String.t(),
            suite_ref: String.t(),
            eval_run_ref: String.t(),
            verdict: :pass | :regress | :improve | :inconclusive,
            case_refs: [String.t()],
            drift_signal_refs: [String.t()],
            redaction_posture: String.t()
          }

    @enforce_keys [
      :studio_ref,
      :tenant_ref,
      :suite_ref,
      :eval_run_ref,
      :verdict,
      :case_refs,
      :drift_signal_refs,
      :redaction_posture
    ]
    defstruct @enforce_keys
  end

  @raw_keys [
    :body,
    :raw_body,
    :payload,
    :raw_payload,
    :eval_payload,
    :expected_output,
    :model_output,
    :provider_payload,
    "body",
    "raw_body",
    "payload",
    "raw_payload",
    "eval_payload",
    "expected_output",
    "model_output",
    "provider_payload"
  ]
  @verdicts [:pass, :regress, :improve, :inconclusive]

  @spec studio(map()) :: {:ok, Studio.t()} | {:error, term()}
  def studio(attrs) when is_map(attrs) do
    with :ok <- reject_raw(attrs),
         :ok <- Components.reject_raw_assigns(attrs),
         {:ok, studio_ref} <- required_string(attrs, :studio_ref),
         {:ok, tenant_ref} <- required_string(attrs, :tenant_ref),
         {:ok, suite_ref} <- required_string(attrs, :suite_ref),
         {:ok, eval_run_ref} <- required_string(attrs, :eval_run_ref),
         {:ok, verdict} <- verdict(attrs),
         {:ok, case_refs} <- string_list(attrs, :case_refs),
         {:ok, drift_signal_refs} <- string_list(attrs, :drift_signal_refs) do
      {:ok,
       %Studio{
         studio_ref: studio_ref,
         tenant_ref: tenant_ref,
         suite_ref: suite_ref,
         eval_run_ref: eval_run_ref,
         verdict: verdict,
         case_refs: case_refs,
         drift_signal_refs: drift_signal_refs,
         redaction_posture: "eval_refs_and_bounded_signals_only"
       }}
    end
  end

  def studio(_attrs), do: {:error, :invalid_eval_studio_attrs}

  defp verdict(attrs) do
    value = fetch(attrs, :verdict)

    if value in @verdicts do
      {:ok, value}
    else
      {:error, :unknown_eval_studio_verdict}
    end
  end

  defp string_list(attrs, field) do
    case fetch(attrs, field, []) do
      values when is_list(values) -> strings_if_safe(values, field)
      _values -> {:error, {:invalid_eval_studio_refs, field}}
    end
  end

  defp strings_if_safe(values, field) do
    if Enum.all?(values, &present_string?/1) do
      {:ok, values}
    else
      {:error, {:invalid_eval_studio_refs, field}}
    end
  end

  defp reject_raw(attrs) do
    case Enum.find(@raw_keys, &Map.has_key?(attrs, &1)) do
      nil -> :ok
      key -> {:error, {:raw_eval_studio_payload_forbidden, key}}
    end
  end

  defp required_string(attrs, field) do
    case fetch(attrs, field) do
      value when is_binary(value) and value != "" -> {:ok, value}
      _value -> {:error, {:missing_eval_studio_ref, field}}
    end
  end

  defp present_string?(value), do: is_binary(value) and String.trim(value) != ""
  defp fetch(attrs, field), do: fetch(attrs, field, nil)

  defp fetch(attrs, field, default),
    do: Map.get(attrs, field) || Map.get(attrs, Atom.to_string(field), default)
end
