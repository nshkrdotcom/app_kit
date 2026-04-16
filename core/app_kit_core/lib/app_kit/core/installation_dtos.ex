defmodule AppKit.Core.InstallTemplate do
  @moduledoc """
  Stable northbound installation template envelope.
  """

  alias AppKit.Core.Support

  @enforce_keys [:template_key, :pack_slug, :pack_version]
  defstruct [:template_key, :pack_slug, :pack_version, default_bindings: %{}, metadata: %{}]

  @type t :: %__MODULE__{
          template_key: String.t(),
          pack_slug: String.t(),
          pack_version: String.t(),
          default_bindings: map(),
          metadata: map()
        }

  @spec new(map() | keyword()) :: {:ok, t()} | {:error, :invalid_install_template}
  def new(attrs) do
    with {:ok, attrs} <- Support.normalize_attrs(attrs),
         template_key <- Map.get(attrs, :template_key),
         true <- Support.present_binary?(template_key),
         pack_slug <- Map.get(attrs, :pack_slug),
         true <- Support.present_binary?(pack_slug),
         pack_version <- Map.get(attrs, :pack_version),
         true <- Support.present_binary?(pack_version),
         default_bindings <- Map.get(attrs, :default_bindings, %{}),
         true <- is_map(default_bindings),
         metadata <- Map.get(attrs, :metadata, %{}),
         true <- is_map(metadata) do
      {:ok,
       %__MODULE__{
         template_key: template_key,
         pack_slug: pack_slug,
         pack_version: pack_version,
         default_bindings: default_bindings,
         metadata: metadata
       }}
    else
      _ -> {:error, :invalid_install_template}
    end
  end
end

defmodule AppKit.Core.InstallationBinding do
  @moduledoc """
  Stable northbound installation binding envelope.
  """

  alias AppKit.Core.Support

  @binding_kinds [:execution, :connector, :evidence, :actor]

  @enforce_keys [:binding_key, :binding_kind]
  defstruct [:binding_key, :binding_kind, config: %{}, credential_ref: nil, metadata: %{}]

  @type binding_kind :: :execution | :connector | :evidence | :actor

  @type t :: %__MODULE__{
          binding_key: String.t(),
          binding_kind: binding_kind(),
          config: map(),
          credential_ref: String.t() | nil,
          metadata: map()
        }

  @spec new(map() | keyword()) :: {:ok, t()} | {:error, :invalid_installation_binding}
  def new(attrs) do
    with {:ok, attrs} <- Support.normalize_attrs(attrs),
         binding_key <- Map.get(attrs, :binding_key),
         true <- Support.present_binary?(binding_key),
         binding_kind <- Map.get(attrs, :binding_kind),
         true <- Support.enum?(binding_kind, @binding_kinds),
         config <- Map.get(attrs, :config, %{}),
         true <- is_map(config),
         credential_ref <- Map.get(attrs, :credential_ref),
         true <- Support.optional_binary?(credential_ref),
         metadata <- Map.get(attrs, :metadata, %{}),
         true <- is_map(metadata) do
      {:ok,
       %__MODULE__{
         binding_key: binding_key,
         binding_kind: binding_kind,
         config: config,
         credential_ref: credential_ref,
         metadata: metadata
       }}
    else
      _ -> {:error, :invalid_installation_binding}
    end
  end
end

defmodule AppKit.Core.InstallResult do
  @moduledoc """
  Stable northbound installation result envelope.
  """

  alias AppKit.Core.{InstallationRef, Support}

  @statuses [:created, :updated, :reused]

  @enforce_keys [:installation_ref, :status]
  defstruct [:installation_ref, :status, message: nil, metadata: %{}]

  @type status :: :created | :updated | :reused

  @type t :: %__MODULE__{
          installation_ref: InstallationRef.t(),
          status: status(),
          message: String.t() | nil,
          metadata: map()
        }

  @spec new(map() | keyword()) :: {:ok, t()} | {:error, :invalid_install_result}
  def new(attrs) do
    with {:ok, attrs} <- Support.normalize_attrs(attrs),
         {:ok, installation_ref} <-
           Support.nested_struct(Map.get(attrs, :installation_ref), InstallationRef),
         false <- is_nil(installation_ref),
         status <- Map.get(attrs, :status),
         true <- Support.enum?(status, @statuses),
         message <- Map.get(attrs, :message),
         true <- Support.optional_binary?(message),
         metadata <- Map.get(attrs, :metadata, %{}),
         true <- is_map(metadata) do
      {:ok,
       %__MODULE__{
         installation_ref: installation_ref,
         status: status,
         message: message,
         metadata: metadata
       }}
    else
      _ -> {:error, :invalid_install_result}
    end
  end
end
