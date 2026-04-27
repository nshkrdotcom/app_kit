defmodule AppKit.Core.Substrate.Ref do
  @moduledoc "Generic AppKit S0 substrate ref DTO."

  alias AppKit.Core.Substrate.{Dump, Support}

  @enforce_keys [:id]
  defstruct [:id, kind: nil, metadata: %{}]

  def new(attrs) when is_binary(attrs), do: new(%{id: attrs})
  def new(%__MODULE__{} = ref), do: {:ok, ref}

  def new(attrs) do
    with {:ok, attrs} <- Support.normalize_attrs(attrs),
         :ok <- Support.reject_selectors(attrs, :invalid_substrate_ref),
         id <- Support.required(attrs, :id),
         true <- Support.safe_ref?(id),
         kind <- Support.optional(attrs, :kind),
         true <- is_nil(kind) or is_atom(kind) or is_binary(kind),
         metadata <- Support.optional(attrs, :metadata, %{}),
         true <- is_map(metadata) do
      {:ok, %__MODULE__{id: id, kind: kind, metadata: metadata}}
    else
      _ -> {:error, :invalid_substrate_ref}
    end
  end

  def new!(attrs), do: new(attrs) |> bang()

  def dump(%__MODULE__{} = ref),
    do: ref |> Map.from_struct() |> Dump.dump_value() |> Dump.drop_nil_values()

  defp bang({:ok, value}), do: value
  defp bang({:error, reason}), do: raise(ArgumentError, Atom.to_string(reason))
end

defmodule AppKit.Core.Substrate.ProfileBundle do
  @moduledoc "AppKit DTO mirror of the S0 profile bundle."

  alias AppKit.Core.Substrate.Dump

  @slots [
    :source_profile_ref,
    :runtime_profile_ref,
    :tool_scope_ref,
    :evidence_profile_ref,
    :publication_profile_ref,
    :review_profile_ref,
    :memory_profile_ref,
    :projection_profile_ref
  ]
  @enforce_keys @slots
  defstruct @slots

  def new(%__MODULE__{} = bundle), do: {:ok, bundle}
  def new(attrs) when is_list(attrs), do: attrs |> Map.new() |> new()

  def new(%{} = attrs) do
    allowed = MapSet.new(Enum.flat_map(@slots, &[&1, Atom.to_string(&1)]))

    with true <- Enum.all?(Map.keys(attrs), &MapSet.member?(allowed, &1)),
         {:ok, values} <- collect(attrs) do
      {:ok, struct!(__MODULE__, values)}
    else
      _ -> {:error, :invalid_profile_bundle}
    end
  end

  def new(_attrs), do: {:error, :invalid_profile_bundle}
  def new!(attrs), do: new(attrs) |> bang()
  def dump(%__MODULE__{} = bundle), do: bundle |> Map.from_struct() |> Dump.dump_value()

  defp collect(attrs) do
    Enum.reduce_while(@slots, {:ok, %{}}, fn slot, {:ok, acc} ->
      value = Map.get(attrs, slot, Map.get(attrs, Atom.to_string(slot)))

      if valid_ref?(slot, value),
        do: {:cont, {:ok, Map.put(acc, slot, value)}},
        else: {:halt, {:error, :invalid_profile_bundle}}
    end)
  end

  defp valid_ref?(:memory_profile_ref, :none), do: true
  defp valid_ref?(:memory_profile_ref, :private_facts_v1), do: true
  defp valid_ref?(_slot, {:custom, value}), do: is_binary(value) and String.trim(value) != ""
  defp valid_ref?(_slot, value), do: is_atom(value) and not is_nil(value)
  defp bang({:ok, value}), do: value
  defp bang({:error, reason}), do: raise(ArgumentError, Atom.to_string(reason))
end

defmodule AppKit.Core.Substrate.RuntimeEventRow do
  @moduledoc "AppKit S0 runtime event row DTO."

  alias AppKit.Core.Substrate.{Dump, Support}

  @required [
    :event_ref,
    :event_seq,
    :event_kind,
    :tenant_ref,
    :installation_ref,
    :subject_ref,
    :run_ref
  ]
  @fields @required ++
            [
              :execution_ref,
              :workflow_ref,
              :turn_ref,
              :level,
              :message_summary,
              :payload_ref,
              :extensions
            ]
  @defaults Map.new(@fields, &{&1, nil}) |> Map.put(:extensions, %{})
  defstruct @required ++
              [
                :execution_ref,
                :workflow_ref,
                :turn_ref,
                :level,
                :message_summary,
                :payload_ref,
                extensions: %{}
              ]

  def new(attrs) do
    with {:ok, attrs} <- Support.normalize_attrs(attrs),
         :ok <- Support.reject_selectors(attrs, :invalid_runtime_event_row),
         true <- Enum.all?(@required, &(Support.required(attrs, &1) |> present?())) do
      {:ok,
       struct!(
         __MODULE__,
         Map.new(@fields, &{&1, Support.optional(attrs, &1, Map.get(@defaults, &1))})
       )}
    else
      _ -> {:error, :invalid_runtime_event_row}
    end
  end

  def dump(%__MODULE__{} = row),
    do: row |> Map.from_struct() |> Dump.dump_value() |> Dump.drop_nil_values()

  defp present?(value) when is_integer(value), do: value >= 0
  defp present?(value), do: Support.safe_ref?(value)
end

defmodule AppKit.Core.Substrate.RuntimeCommandResult do
  @moduledoc "AppKit S0 command result DTO."
  alias AppKit.Core.Substrate.{Dump, Support}

  @required [:command_ref, :command_kind, :status, :idempotency_key]
  @fields @required ++
            [
              :accepted?,
              :coalesced?,
              :authority_state,
              :authority_refs,
              :workflow_effect_state,
              :projection_state,
              :trace_id,
              :correlation_id,
              :message,
              :diagnostics
            ]
  @defaults Map.new(@fields, &{&1, nil})
            |> Map.merge(%{
              accepted?: false,
              coalesced?: false,
              authority_refs: [],
              diagnostics: []
            })
  defstruct @required ++
              [
                :accepted?,
                :coalesced?,
                :authority_state,
                :authority_refs,
                :workflow_effect_state,
                :projection_state,
                :trace_id,
                :correlation_id,
                :message,
                diagnostics: []
              ]

  def new(attrs) do
    with {:ok, attrs} <- Support.normalize_attrs(attrs),
         :ok <- Support.reject_selectors(attrs, :invalid_runtime_command_result),
         true <- Enum.all?(@required, &(Support.required(attrs, &1) |> present?())) do
      {:ok,
       struct!(
         __MODULE__,
         Map.new(@fields, &{&1, Support.optional(attrs, &1, Map.get(@defaults, &1))})
       )}
    else
      _ -> {:error, :invalid_runtime_command_result}
    end
  end

  def dump(%__MODULE__{} = result),
    do: result |> Map.from_struct() |> Dump.dump_value() |> Dump.drop_nil_values()

  defp present?(value), do: Support.safe_ref?(value) or is_atom(value)
end

defmodule AppKit.Core.Substrate.RuntimeProjectionEnvelope do
  @moduledoc "AppKit S0 projection envelope DTO."
  alias AppKit.Core.Substrate.{Dump, Support}

  @required [
    :schema_ref,
    :schema_version,
    :projection_ref,
    :projection_name,
    :projection_kind,
    :tenant_ref,
    :installation_ref,
    :profile_ref,
    :scope_ref,
    :row_key,
    :payload
  ]
  @fields @required ++
            [
              :updated_at,
              :computed_at,
              :staleness_ms,
              :trace_id,
              :causation_id,
              :diagnostics
            ]
  @defaults Map.new(@fields, &{&1, nil}) |> Map.merge(%{payload: %{}, diagnostics: []})
  defstruct @required ++
              [
                :updated_at,
                :computed_at,
                :staleness_ms,
                :trace_id,
                :causation_id,
                diagnostics: []
              ]

  def new(attrs) do
    with {:ok, attrs} <- Support.normalize_attrs(attrs),
         :ok <- Support.reject_selectors(attrs, :invalid_runtime_projection_envelope),
         true <- Enum.all?(@required, &(Support.required(attrs, &1) |> present?())) do
      {:ok,
       struct!(
         __MODULE__,
         Map.new(@fields, &{&1, Support.optional(attrs, &1, Map.get(@defaults, &1))})
       )}
    else
      _ -> {:error, :invalid_runtime_projection_envelope}
    end
  end

  def dump(%__MODULE__{} = envelope),
    do: envelope |> Map.from_struct() |> Dump.dump_value() |> Dump.drop_nil_values()

  defp present?(value) when is_integer(value), do: value >= 0
  defp present?(value) when is_map(value), do: true
  defp present?(value), do: Support.safe_ref?(value) or is_atom(value)
end
