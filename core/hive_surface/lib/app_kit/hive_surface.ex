defmodule AppKit.HiveSurface do
  @moduledoc """
  DTO-only surface for governed multi-agent coordination.
  """

  alias JidoHive.AgentCoordinator.CoordinationRecord
  alias JidoHive.CoordinationPatterns.PatternSpec
  alias JidoHive.InterAgentMessaging.RoutedMessage
  alias JidoHive.SharedMemoryFacade.Decision

  defmodule HiveProjection do
    @moduledoc "Operator-safe multi-agent projection."
    @enforce_keys [
      :projection_ref,
      :tenant_ref,
      :installation_ref,
      :agent_refs,
      :message_refs,
      :memory_scope_refs,
      :pattern_refs,
      :budget_refs,
      :trace_refs,
      :redaction_posture
    ]
    defstruct @enforce_keys

    @type t :: %__MODULE__{}
  end

  defmodule HiveTraceProjection do
    @moduledoc "AITrace-compatible refs-only hive projection."
    @enforce_keys [
      :trace_ref,
      :tenant_ref,
      :installation_ref,
      :workflow_lifecycle_ref,
      :agent_refs,
      :message_refs,
      :memory_scope_refs,
      :pattern_refs,
      :redaction_posture
    ]
    defstruct @enforce_keys

    @type t :: %__MODULE__{}
  end

  @raw_keys [
    :agent_message_body,
    :authorization,
    :authorization_header,
    :body,
    :credential,
    :memory_body,
    :message_body,
    :payload,
    :private_state,
    :prompt_body,
    :provider_payload,
    :raw_body,
    :secret,
    :skill_private_state,
    :token,
    :tool_output,
    "agent_message_body",
    "authorization",
    "authorization_header",
    "body",
    "credential",
    "memory_body",
    "message_body",
    "payload",
    "private_state",
    "prompt_body",
    "provider_payload",
    "raw_body",
    "secret",
    "skill_private_state",
    "token",
    "tool_output"
  ]

  @spec projection(map()) :: {:ok, HiveProjection.t()} | {:error, term()}
  def projection(attrs) when is_map(attrs) do
    with :ok <- reject_raw(attrs),
         :ok <- required_strings(attrs, [:projection_ref, :tenant_ref, :installation_ref]),
         :ok <-
           required_lists(attrs, [
             :agent_refs,
             :message_refs,
             :memory_scope_refs,
             :pattern_refs,
             :budget_refs,
             :trace_refs
           ]) do
      {:ok,
       %HiveProjection{
         projection_ref: fetch!(attrs, :projection_ref),
         tenant_ref: fetch!(attrs, :tenant_ref),
         installation_ref: fetch!(attrs, :installation_ref),
         agent_refs: fetch!(attrs, :agent_refs),
         message_refs: fetch!(attrs, :message_refs),
         memory_scope_refs: fetch!(attrs, :memory_scope_refs),
         pattern_refs: fetch!(attrs, :pattern_refs),
         budget_refs: fetch!(attrs, :budget_refs),
         trace_refs: fetch!(attrs, :trace_refs),
         redaction_posture: redaction_posture(attrs)
       }}
    end
  end

  def projection(_attrs), do: {:error, :invalid_hive_projection}

  @spec from_records(map()) :: {:ok, HiveProjection.t()} | {:error, term()}
  def from_records(attrs) when is_map(attrs) do
    with :ok <- reject_raw(attrs),
         {:ok, agents} <- typed_list(attrs, :agents, CoordinationRecord),
         {:ok, messages} <- typed_list(attrs, :messages, RoutedMessage),
         {:ok, memory_decisions} <- typed_list(attrs, :memory_decisions, Decision),
         {:ok, patterns} <- typed_list(attrs, :patterns, PatternSpec) do
      projection(%{
        projection_ref: fetch(attrs, :projection_ref) || "hive-projection://records",
        tenant_ref: common_ref(agents, :tenant_ref),
        installation_ref: common_ref(agents, :installation_ref),
        agent_refs: Enum.map(agents, & &1.agent_ref),
        message_refs: Enum.map(messages, & &1.message_ref),
        memory_scope_refs: Enum.map(memory_decisions, & &1.memory_scope_ref),
        pattern_refs: Enum.map(patterns, & &1.pattern_ref),
        budget_refs: Enum.map(agents, & &1.budget_ref),
        trace_refs: Enum.map(agents, & &1.trace_ref),
        redaction_posture: "refs_only"
      })
    end
  end

  def from_records(_attrs), do: {:error, :invalid_hive_records}

  @spec trace_projection(map()) :: {:ok, HiveTraceProjection.t()} | {:error, term()}
  def trace_projection(attrs) when is_map(attrs) do
    with {:ok, projection} <- projection(attrs),
         :ok <- required_strings(attrs, [:trace_ref, :workflow_lifecycle_ref]) do
      {:ok,
       %HiveTraceProjection{
         trace_ref: fetch!(attrs, :trace_ref),
         tenant_ref: projection.tenant_ref,
         installation_ref: projection.installation_ref,
         workflow_lifecycle_ref: fetch!(attrs, :workflow_lifecycle_ref),
         agent_refs: projection.agent_refs,
         message_refs: projection.message_refs,
         memory_scope_refs: projection.memory_scope_refs,
         pattern_refs: projection.pattern_refs,
         redaction_posture: projection.redaction_posture
       }}
    end
  end

  def trace_projection(_attrs), do: {:error, :invalid_hive_trace_projection}

  defp typed_list(attrs, key, module) do
    case fetch(attrs, key) do
      values when is_list(values) -> validate_typed_list(values, key, module)
      _other -> {:error, {:invalid_record_list, key}}
    end
  end

  defp validate_typed_list(values, key, module) do
    if Enum.all?(values, &match?(%{__struct__: ^module}, &1)) do
      {:ok, values}
    else
      {:error, {:invalid_record_list, key}}
    end
  end

  defp common_ref([first | rest], key) do
    first_value = Map.fetch!(first, key)

    if Enum.all?(rest, &(Map.fetch!(&1, key) == first_value)) do
      first_value
    else
      "mixed-ref"
    end
  end

  defp common_ref([], _key), do: "empty-ref"

  defp required_strings(attrs, keys) do
    Enum.reduce_while(keys, :ok, fn key, :ok ->
      case fetch(attrs, key) do
        value when is_binary(value) and value != "" -> {:cont, :ok}
        _other -> {:halt, {:error, {:missing_ref, key}}}
      end
    end)
  end

  defp required_lists(attrs, keys) do
    Enum.reduce_while(keys, :ok, fn key, :ok ->
      case fetch(attrs, key) do
        values when is_list(values) -> {:cont, :ok}
        _other -> {:halt, {:error, {:missing_list, key}}}
      end
    end)
  end

  defp redaction_posture(attrs), do: fetch(attrs, :redaction_posture) || "refs_only"

  defp fetch!(attrs, key), do: fetch(attrs, key)

  defp fetch(attrs, key) do
    Map.get(attrs, key) || Map.get(attrs, Atom.to_string(key))
  end

  defp reject_raw(value), do: reject_raw(value, [])

  defp reject_raw(%_struct{} = value, path), do: value |> Map.from_struct() |> reject_raw(path)

  defp reject_raw(%{} = map, path) do
    Enum.reduce_while(map, :ok, fn {key, value}, :ok ->
      reject_raw_entry(key, value, path)
    end)
  end

  defp reject_raw(list, path) when is_list(list) do
    Enum.reduce_while(list, :ok, fn value, :ok ->
      case reject_raw(value, path) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp reject_raw(_value, _path), do: :ok

  defp reject_raw_entry(key, value, path) do
    if key in @raw_keys do
      {:halt, {:error, {:raw_field_rejected, Enum.reverse([key | path])}}}
    else
      reject_nested_raw(key, value, path)
    end
  end

  defp reject_nested_raw(key, value, path) do
    case reject_raw(value, [key | path]) do
      :ok -> {:cont, :ok}
      {:error, reason} -> {:halt, {:error, reason}}
    end
  end
end
