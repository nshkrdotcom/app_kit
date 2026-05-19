defmodule AppKit.Core.RuntimeReadback.Diagnostic do
  @moduledoc "Operator-safe runtime diagnostic DTO."

  alias AppKit.Core.RuntimeReadback.Support

  @severity_atoms [:debug, :info, :warning, :error]
  @severity_lookup Map.new(@severity_atoms, &{Atom.to_string(&1), &1})
  defstruct [:severity, :code, :message, :source_ref, :trace_ref, :semantic_failure_ref]

  def new(%__MODULE__{} = value), do: {:ok, value}

  def new(attrs) do
    with {:ok, attrs, nil} <- Support.normalize(attrs),
         :ok <- Support.reject_selectors(attrs, :invalid_diagnostic),
         {:ok, severity} <- normalize_severity(Support.optional(attrs, :severity, :info)),
         code <- Support.optional(attrs, :code),
         true <- is_nil(code) or Support.present_binary?(code),
         message <- Support.optional(attrs, :message),
         true <- is_nil(message) or is_binary(message),
         source_ref <- Support.optional(attrs, :source_ref),
         true <- Support.optional_ref?(source_ref),
         trace_ref <- Support.optional(attrs, :trace_ref),
         true <- Support.optional_ref?(trace_ref),
         semantic_failure_ref <- Support.optional(attrs, :semantic_failure_ref),
         true <- Support.optional_ref?(semantic_failure_ref) do
      {:ok,
       %__MODULE__{
         severity: severity,
         code: code,
         message: message,
         source_ref: source_ref,
         trace_ref: trace_ref,
         semantic_failure_ref: semantic_failure_ref
       }}
    else
      _ -> {:error, :invalid_diagnostic}
    end
  end

  def dump(%__MODULE__{} = value), do: Support.dump_struct(value)

  defp normalize_severity(value) when is_atom(value) do
    if value in @severity_atoms do
      {:ok, value}
    else
      :error
    end
  end

  defp normalize_severity(value) when is_binary(value), do: Map.fetch(@severity_lookup, value)
  defp normalize_severity(_value), do: :error
end
