defmodule AppKit.SkillSurface do
  @moduledoc """
  DTO-only surface for governed skill admission and invocation.
  """

  @skill_contracts Module.concat([Jido, Integration, V2, SkillContracts])
  @skill_package Module.concat([@skill_contracts, SkillPackage])

  defmodule SkillAdmissionRequest do
    @moduledoc "Skill admission request DTO."
    @enforce_keys [:request_ref, :operator_ref, :manifest]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            request_ref: String.t(),
            operator_ref: String.t(),
            manifest: struct()
          }
  end

  defmodule SkillInvocationRequest do
    @moduledoc "Skill invocation request DTO."
    @enforce_keys [:request_ref, :operator_ref, :intent]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            request_ref: String.t(),
            operator_ref: String.t(),
            intent: struct()
          }
  end

  defmodule SkillProjection do
    @moduledoc "Operator-safe skill projection DTO."
    @enforce_keys [
      :skill_ref,
      :package_name,
      :version,
      :manifest_hash,
      :tenant_ref,
      :installation_ref,
      :policy_refs,
      :capability_refs,
      :docs_ref,
      :trace_ref,
      :release_manifest_ref,
      :redaction_posture,
      :admission_status,
      :pending_approval_refs
    ]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            skill_ref: String.t(),
            package_name: String.t(),
            version: String.t(),
            manifest_hash: String.t(),
            tenant_ref: String.t(),
            installation_ref: String.t(),
            policy_refs: [String.t()],
            capability_refs: [String.t()],
            docs_ref: String.t(),
            trace_ref: String.t(),
            release_manifest_ref: String.t(),
            redaction_posture: String.t(),
            admission_status: atom(),
            pending_approval_refs: [String.t()]
          }
  end

  defmodule SkillTraceProjection do
    @moduledoc "Trace projection DTO for skill events."
    @enforce_keys [
      :trace_ref,
      :skill_ref,
      :manifest_hash,
      :policy_refs,
      :capability_refs,
      :release_manifest_ref,
      :redaction_posture
    ]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            trace_ref: String.t(),
            skill_ref: String.t(),
            manifest_hash: String.t(),
            policy_refs: [String.t()],
            capability_refs: [String.t()],
            release_manifest_ref: String.t(),
            redaction_posture: String.t()
          }
  end

  @raw_keys [
    :authorization,
    :authorization_header,
    :body,
    :command,
    :content,
    :credential,
    :credentials,
    :cwd,
    :env,
    :memory_body,
    :private_state,
    :private_state_body,
    :prompt_body,
    :provider_account_id,
    :provider_payload,
    :raw_authorization,
    :raw_body,
    :raw_content,
    :raw_credential,
    :raw_endpoint,
    :raw_memory,
    :raw_private_state,
    :raw_prompt,
    :raw_secret,
    :raw_token,
    :script_path,
    :secret,
    :shell_args,
    :token,
    "authorization",
    "authorization_header",
    "body",
    "command",
    "content",
    "credential",
    "credentials",
    "cwd",
    "env",
    "memory_body",
    "private_state",
    "private_state_body",
    "prompt_body",
    "provider_account_id",
    "provider_payload",
    "raw_authorization",
    "raw_body",
    "raw_content",
    "raw_credential",
    "raw_endpoint",
    "raw_memory",
    "raw_private_state",
    "raw_prompt",
    "raw_secret",
    "raw_token",
    "script_path",
    "secret",
    "shell_args",
    "token"
  ]

  @spec admission_request(map()) :: {:ok, SkillAdmissionRequest.t()} | {:error, term()}
  def admission_request(attrs) when is_map(attrs) do
    with :ok <- reject_raw(attrs),
         :ok <- required_strings(attrs, [:request_ref, :operator_ref]),
         {:ok, manifest} <- attrs |> fetch(:manifest) |> @skill_contracts.package() do
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
         {:ok, intent} <- attrs |> fetch(:intent) |> @skill_contracts.invocation_intent() do
      {:ok,
       %SkillInvocationRequest{
         request_ref: fetch!(attrs, :request_ref),
         operator_ref: fetch!(attrs, :operator_ref),
         intent: intent
       }}
    end
  end

  def invocation_request(_attrs), do: {:error, :invalid_skill_invocation_request}

  @spec projection(struct() | map()) :: {:ok, SkillProjection.t()} | {:error, term()}
  def projection(%module{} = manifest) when module == @skill_package do
    manifest
    |> @skill_contracts.projection()
    |> projection_from_contract()
  end

  def projection(attrs) when is_map(attrs) do
    with :ok <- reject_raw(attrs),
         {:ok, manifest} <- attrs |> fetch(:manifest, attrs) |> @skill_contracts.package() do
      projection(manifest)
    end
  end

  def projection(_attrs), do: {:error, :invalid_skill_projection}

  @spec trace_projection(struct() | map()) ::
          {:ok, SkillTraceProjection.t()} | {:error, term()}
  def trace_projection(%module{} = manifest) when module == @skill_package do
    manifest
    |> @skill_contracts.trace_projection()
    |> trace_from_contract()
  end

  def trace_projection(attrs) when is_map(attrs) do
    with :ok <- reject_raw(attrs),
         {:ok, manifest} <- attrs |> fetch(:manifest, attrs) |> @skill_contracts.package() do
      trace_projection(manifest)
    end
  end

  def trace_projection(_attrs), do: {:error, :invalid_skill_trace_projection}

  @spec canonical_manifest_hash(map()) :: String.t()
  def canonical_manifest_hash(attrs) when is_map(attrs) do
    @skill_contracts.canonical_manifest_hash(attrs)
  end

  defp projection_from_contract(attrs) do
    {:ok,
     %SkillProjection{
       skill_ref: attrs.skill_ref,
       package_name: attrs.package_name,
       version: attrs.version,
       manifest_hash: attrs.manifest_hash,
       tenant_ref: attrs.tenant_ref,
       installation_ref: attrs.installation_ref,
       policy_refs: attrs.policy_refs,
       capability_refs: attrs.capability_refs,
       docs_ref: attrs.docs_ref,
       trace_ref: attrs.trace_ref,
       release_manifest_ref: attrs.release_manifest_ref,
       redaction_posture: attrs.redaction_posture,
       admission_status: attrs.admission_status,
       pending_approval_refs: Map.get(attrs, :pending_approval_refs, [])
     }}
  end

  defp trace_from_contract(attrs) do
    {:ok,
     %SkillTraceProjection{
       trace_ref: attrs.trace_ref,
       skill_ref: attrs.skill_ref,
       manifest_hash: attrs.manifest_hash,
       policy_refs: attrs.policy_refs,
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
