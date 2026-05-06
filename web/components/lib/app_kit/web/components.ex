defmodule AppKit.Web.Components do
  @moduledoc """
  Redaction-aware component contracts for operator-facing views.
  """

  defmodule Field do
    @moduledoc "Single safe field component."
    @enforce_keys [:component, :label, :value, :redaction_posture]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            component: atom(),
            label: String.t(),
            value: String.t(),
            redaction_posture: String.t()
          }
  end

  defmodule ProjectionTable do
    @moduledoc "Projection table component with safe rows."
    @enforce_keys [:component, :table_ref, :tenant_ref, :columns, :rows, :redaction_posture]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            component: :projection_table,
            table_ref: String.t(),
            tenant_ref: String.t(),
            columns: [String.t()],
            rows: [map()],
            redaction_posture: String.t()
          }
  end

  defmodule SourceViolation do
    @moduledoc "Source policy violation."
    @enforce_keys [:line, :fragment]
    defstruct @enforce_keys

    @type t :: %__MODULE__{line: pos_integer(), fragment: String.t()}
  end

  @safe_components [
    :ref_badge,
    :hash_badge,
    :redacted_excerpt,
    :timestamp,
    :decision_class,
    :proof_link,
    :timeline_card,
    :audit_hash_chain
  ]
  @forbidden_assign_keys [
    :body,
    :raw_body,
    :payload,
    :raw_payload,
    :prompt_body,
    :raw_prompt,
    :memory_body,
    :raw_memory_body,
    :provider_payload,
    :provider_response,
    :eval_payload,
    :model_output,
    :credential,
    :authorization_header,
    :auth_header,
    :token,
    :secret,
    :private_state,
    :agent_message_body,
    "body",
    "raw_body",
    "payload",
    "raw_payload",
    "prompt_body",
    "raw_prompt",
    "memory_body",
    "raw_memory_body",
    "provider_payload",
    "provider_response",
    "eval_payload",
    "model_output",
    "credential",
    "authorization_header",
    "auth_header",
    "token",
    "secret",
    "private_state",
    "agent_message_body"
  ]

  @spec field(map()) :: {:ok, Field.t()} | {:error, term()}
  def field(attrs) when is_map(attrs) do
    with :ok <- reject_raw_assigns(attrs),
         {:ok, component} <- component(attrs),
         {:ok, label} <- required_string(attrs, :label),
         {:ok, value} <- required_string(attrs, :value) do
      {:ok,
       %Field{
         component: component,
         label: label,
         value: value,
         redaction_posture: redaction_posture(attrs)
       }}
    end
  end

  def field(_attrs), do: {:error, :invalid_component_attrs}

  @spec ref_badge(String.t(), String.t()) :: {:ok, Field.t()} | {:error, term()}
  def ref_badge(label, ref), do: field(%{component: :ref_badge, label: label, value: ref})

  @spec hash_badge(String.t(), String.t()) :: {:ok, Field.t()} | {:error, term()}
  def hash_badge(label, hash), do: field(%{component: :hash_badge, label: label, value: hash})

  @spec decision_class(String.t(), atom() | String.t()) :: {:ok, Field.t()} | {:error, term()}
  def decision_class(label, value) when is_atom(value),
    do: decision_class(label, Atom.to_string(value))

  def decision_class(label, value),
    do: field(%{component: :decision_class, label: label, value: value})

  @spec projection_table(map()) :: {:ok, ProjectionTable.t()} | {:error, term()}
  def projection_table(attrs) when is_map(attrs) do
    with :ok <- reject_raw_assigns(attrs),
         {:ok, table_ref} <- required_string(attrs, :table_ref),
         {:ok, tenant_ref} <- required_string(attrs, :tenant_ref),
         {:ok, columns} <- string_list(attrs, :columns),
         {:ok, rows} <- safe_rows(attrs) do
      {:ok,
       %ProjectionTable{
         component: :projection_table,
         table_ref: table_ref,
         tenant_ref: tenant_ref,
         columns: columns,
         rows: rows,
         redaction_posture: "safe_assigns_only"
       }}
    end
  end

  def projection_table(_attrs), do: {:error, :invalid_projection_table}

  @spec reject_raw_assigns(term()) :: :ok | {:error, {:forbidden_assign_name, String.t()}}
  def reject_raw_assigns(term) do
    case find_forbidden_assign(term) do
      nil -> :ok
      key -> {:error, {:forbidden_assign_name, to_string(key)}}
    end
  end

  @spec source_policy(String.t(), [String.t()]) :: :ok | {:error, [SourceViolation.t()]}
  def source_policy(source, forbidden_fragments)
      when is_binary(source) and is_list(forbidden_fragments) do
    violations =
      source
      |> String.split("\n")
      |> Enum.with_index(1)
      |> Enum.flat_map(fn {line, line_number} ->
        line
        |> strip_comment()
        |> line_violations(line_number, forbidden_fragments)
      end)

    case violations do
      [] -> :ok
      violations -> {:error, violations}
    end
  end

  defp component(attrs) do
    value = fetch(attrs, :component)

    if value in @safe_components do
      {:ok, value}
    else
      {:error, :unknown_safe_component}
    end
  end

  defp safe_rows(attrs) do
    case fetch(attrs, :rows, []) do
      rows when is_list(rows) -> rows_if_safe(rows)
      _rows -> {:error, :invalid_projection_rows}
    end
  end

  defp string_list(attrs, field) do
    case fetch(attrs, field) do
      values when is_list(values) -> strings_if_safe(values, field)
      _values -> {:error, {:invalid_component_string_list, field}}
    end
  end

  defp rows_if_safe(rows) do
    if Enum.all?(rows, &is_map/1) do
      {:ok, rows}
    else
      {:error, :invalid_projection_rows}
    end
  end

  defp strings_if_safe(values, field) do
    if Enum.all?(values, &present_string?/1) do
      {:ok, values}
    else
      {:error, {:invalid_component_string_list, field}}
    end
  end

  defp redaction_posture(attrs), do: fetch(attrs, :redaction_posture, "bounded_refs_only")

  defp find_forbidden_assign(%_{} = struct),
    do: struct |> Map.from_struct() |> find_forbidden_assign()

  defp find_forbidden_assign(%{} = map) do
    Enum.find_value(map, fn {key, value} ->
      if key in @forbidden_assign_keys do
        key
      else
        find_forbidden_assign(value)
      end
    end)
  end

  defp find_forbidden_assign(values) when is_list(values) do
    Enum.find_value(values, &find_forbidden_assign/1)
  end

  defp find_forbidden_assign(_value), do: nil

  defp line_violations(line, line_number, fragments) do
    fragments
    |> Enum.filter(&(present_string?(&1) and String.contains?(line, &1)))
    |> Enum.map(&%SourceViolation{line: line_number, fragment: &1})
  end

  defp strip_comment(line) do
    line
    |> String.split("#", parts: 2)
    |> List.first()
  end

  defp required_string(attrs, field) do
    case fetch(attrs, field) do
      value when is_binary(value) and value != "" -> {:ok, value}
      _value -> {:error, {:missing_component_field, field}}
    end
  end

  defp present_string?(value), do: is_binary(value) and String.trim(value) != ""
  defp fetch(attrs, field), do: fetch(attrs, field, nil)

  defp fetch(attrs, field, default),
    do: Map.get(attrs, field) || Map.get(attrs, Atom.to_string(field), default)
end
