defmodule AppKit.SkillSurface do
  @moduledoc """
  DTO-only surface for governed skill admission and invocation.
  """

  alias JidoHive.SkillContracts
  alias JidoHive.SkillContracts.SkillInvocationIntent
  alias JidoHive.SkillContracts.SkillManifest

  defmodule SkillAdmissionRequest do
    @moduledoc "Skill admission request DTO."
    @enforce_keys [:request_ref, :operator_ref, :manifest]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            request_ref: String.t(),
            operator_ref: String.t(),
            manifest: SkillManifest.t()
          }
  end

  defmodule SkillInvocationRequest do
    @moduledoc "Skill invocation request DTO."
    @enforce_keys [:request_ref, :operator_ref, :intent]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            request_ref: String.t(),
            operator_ref: String.t(),
            intent: SkillInvocationIntent.t()
          }
  end

  defmodule SkillProjection do
    @moduledoc "Operator-safe skill projection DTO."
    @enforce_keys [
      :skill_ref,
      :version_ref,
      :revision,
      :tenant_ref,
      :installation_ref,
      :prompt_ref,
      :tool_refs,
      :memory_profile_ref,
      :guard_policy_ref,
      :eval_suite_ref,
      :budget_profile_ref,
      :conformance_ref,
      :capability_refs,
      :trace_ref,
      :release_manifest_ref,
      :redaction_posture
    ]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            skill_ref: String.t(),
            version_ref: String.t(),
            revision: pos_integer(),
            tenant_ref: String.t(),
            installation_ref: String.t(),
            prompt_ref: String.t(),
            tool_refs: [String.t()],
            memory_profile_ref: String.t(),
            guard_policy_ref: String.t(),
            eval_suite_ref: String.t(),
            budget_profile_ref: String.t(),
            conformance_ref: String.t(),
            capability_refs: [String.t()],
            trace_ref: String.t(),
            release_manifest_ref: String.t(),
            redaction_posture: String.t()
          }
  end

  defmodule SkillTraceProjection do
    @moduledoc "Trace projection DTO for skill events."
    @enforce_keys [
      :trace_ref,
      :skill_ref,
      :version_ref,
      :prompt_ref,
      :guard_policy_ref,
      :eval_suite_ref,
      :budget_profile_ref,
      :capability_refs,
      :release_manifest_ref,
      :redaction_posture
    ]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            trace_ref: String.t(),
            skill_ref: String.t(),
            version_ref: String.t(),
            prompt_ref: String.t(),
            guard_policy_ref: String.t(),
            eval_suite_ref: String.t(),
            budget_profile_ref: String.t(),
            capability_refs: [String.t()],
            release_manifest_ref: String.t(),
            redaction_posture: String.t()
          }
  end

  @raw_keys [
    :authorization,
    :authorization_header,
    :body,
    :content,
    :credential,
    :credentials,
    :memory_body,
    :private_state,
    :private_state_body,
    :prompt_body,
    :provider_account_id,
    :provider_payload,
    :raw_authorization,
    :raw_body,
    :raw_content,
    :raw_memory,
    :raw_private_state,
    :raw_prompt,
    :raw_secret,
    :raw_token,
    :secret,
    :token,
    "authorization",
    "authorization_header",
    "body",
    "content",
    "credential",
    "credentials",
    "memory_body",
    "private_state",
    "private_state_body",
    "prompt_body",
    "provider_account_id",
    "provider_payload",
    "raw_authorization",
    "raw_body",
    "raw_content",
    "raw_memory",
    "raw_private_state",
    "raw_prompt",
    "raw_secret",
    "raw_token",
    "secret",
    "token"
  ]

  @spec admission_request(map()) :: {:ok, SkillAdmissionRequest.t()} | {:error, term()}
  def admission_request(attrs) when is_map(attrs) do
    with :ok <- reject_raw(attrs),
         :ok <- required_strings(attrs, [:request_ref, :operator_ref]),
         {:ok, manifest} <- attrs |> fetch(:manifest) |> SkillContracts.manifest() do
      {:ok,
       %SkillAdmissionRequest{
         request_ref: fetch!(attrs, :request_ref),
         operator_ref: fetch!(attrs, :operator_ref),
         manifest: manifest
       }}
    end
  end

  def admission_request(_attrs), do: {:error, :invalid_skill_admission_request}

  @spec invocation_request(map()) :: {:ok, SkillInvocationRequest.t()} | {:error, term()}
  def invocation_request(attrs) when is_map(attrs) do
    with :ok <- reject_raw(attrs),
         :ok <- required_strings(attrs, [:request_ref, :operator_ref]),
         {:ok, intent} <- attrs |> fetch(:intent) |> SkillContracts.invocation_intent() do
      {:ok,
       %SkillInvocationRequest{
         request_ref: fetch!(attrs, :request_ref),
         operator_ref: fetch!(attrs, :operator_ref),
         intent: intent
       }}
    end
  end

  def invocation_request(_attrs), do: {:error, :invalid_skill_invocation_request}

  @spec projection(SkillManifest.t() | map()) :: {:ok, SkillProjection.t()} | {:error, term()}
  def projection(%SkillManifest{} = manifest) do
    manifest
    |> SkillContracts.projection()
    |> projection_from_contract()
  end

  def projection(attrs) when is_map(attrs) do
    with :ok <- reject_raw(attrs),
         {:ok, manifest} <- attrs |> fetch(:manifest, attrs) |> SkillContracts.manifest() do
      projection(manifest)
    end
  end

  def projection(_attrs), do: {:error, :invalid_skill_projection}

  @spec trace_projection(SkillManifest.t() | map()) ::
          {:ok, SkillTraceProjection.t()} | {:error, term()}
  def trace_projection(%SkillManifest{} = manifest) do
    manifest
    |> SkillContracts.trace_projection()
    |> trace_from_contract()
  end

  def trace_projection(attrs) when is_map(attrs) do
    with :ok <- reject_raw(attrs),
         {:ok, manifest} <- attrs |> fetch(:manifest, attrs) |> SkillContracts.manifest() do
      trace_projection(manifest)
    end
  end

  def trace_projection(_attrs), do: {:error, :invalid_skill_trace_projection}

  defp projection_from_contract(attrs) do
    {:ok,
     %SkillProjection{
       skill_ref: attrs.skill_ref,
       version_ref: attrs.version_ref,
       revision: attrs.revision,
       tenant_ref: attrs.tenant_ref,
       installation_ref: attrs.installation_ref,
       prompt_ref: attrs.prompt_ref,
       tool_refs: attrs.tool_refs,
       memory_profile_ref: attrs.memory_profile_ref,
       guard_policy_ref: attrs.guard_policy_ref,
       eval_suite_ref: attrs.eval_suite_ref,
       budget_profile_ref: attrs.budget_profile_ref,
       conformance_ref: attrs.conformance_ref,
       capability_refs: attrs.capability_refs,
       trace_ref: attrs.trace_ref,
       release_manifest_ref: attrs.release_manifest_ref,
       redaction_posture: attrs.redaction_posture
     }}
  end

  defp trace_from_contract(attrs) do
    {:ok,
     %SkillTraceProjection{
       trace_ref: attrs.trace_ref,
       skill_ref: attrs.skill_ref,
       version_ref: attrs.version_ref,
       prompt_ref: attrs.prompt_ref,
       guard_policy_ref: attrs.guard_policy_ref,
       eval_suite_ref: attrs.eval_suite_ref,
       budget_profile_ref: attrs.budget_profile_ref,
       capability_refs: attrs.capability_refs,
       release_manifest_ref: attrs.release_manifest_ref,
       redaction_posture: attrs.redaction_posture
     }}
  end

  defp reject_raw(attrs), do: reject_raw(attrs, [])

  defp reject_raw(value, path) when is_map(value) do
    value
    |> map_entries()
    |> Enum.reduce_while(:ok, fn {key, nested_value}, :ok ->
      reject_raw_map_entry(key, nested_value, path)
    end)
  end

  defp reject_raw(values, path) when is_list(values) do
    values
    |> Enum.with_index()
    |> Enum.reduce_while(:ok, fn {value, index}, :ok ->
      case reject_raw(value, [index | path]) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp reject_raw(_value, _path), do: :ok

  defp reject_raw_map_entry(key, _nested_value, path) when key in @raw_keys do
    {:halt, {:error, {:raw_skill_surface_field_forbidden, Enum.reverse([key | path])}}}
  end

  defp reject_raw_map_entry(key, nested_value, path) do
    reject_nested_raw(nested_value, [key | path])
  end

  defp reject_nested_raw(nested_value, path) do
    case reject_raw(nested_value, path) do
      :ok -> {:cont, :ok}
      {:error, reason} -> {:halt, {:error, reason}}
    end
  end

  defp required_strings(attrs, fields) do
    case Enum.find(fields, &(not present_string?(fetch(attrs, &1)))) do
      nil -> :ok
      field -> {:error, {:missing_skill_surface_ref, field}}
    end
  end

  defp map_entries(%module{} = value) when is_atom(module) do
    value
    |> Map.from_struct()
    |> Map.to_list()
  end

  defp map_entries(value), do: Map.to_list(value)

  defp fetch!(attrs, field), do: fetch(attrs, field)
  defp fetch(attrs, field), do: fetch(attrs, field, nil)

  defp fetch(attrs, field, default) do
    cond do
      Map.has_key?(attrs, field) -> Map.fetch!(attrs, field)
      Map.has_key?(attrs, Atom.to_string(field)) -> Map.fetch!(attrs, Atom.to_string(field))
      true -> default
    end
  end

  defp present_string?(value), do: is_binary(value) and String.trim(value) != ""
end
