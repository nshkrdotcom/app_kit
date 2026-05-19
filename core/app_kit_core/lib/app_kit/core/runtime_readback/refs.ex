defmodule AppKit.Core.RuntimeReadback.SessionRef do
  @moduledoc "Opaque runtime session ref for public readback DTOs."

  alias AppKit.Core.RuntimeReadback.Support

  @enforce_keys [:id]
  defstruct [:id, :kind, metadata: %{}]

  def new(%__MODULE__{} = value), do: {:ok, value}

  def new(attrs) when is_binary(attrs), do: new(%{id: attrs})

  def new(attrs) do
    with {:ok, attrs, nil} <- Support.normalize(attrs),
         :ok <- Support.reject_selectors(attrs, :invalid_session_ref),
         id when is_binary(id) <- Support.required(attrs, :id),
         true <- Support.safe_ref?(id),
         kind <- Support.optional(attrs, :kind),
         true <- Support.optional_atomish?(kind),
         metadata <- Support.optional(attrs, :metadata, %{}),
         true <- is_map(metadata) do
      {:ok, %__MODULE__{id: id, kind: kind, metadata: metadata}}
    else
      _ -> {:error, :invalid_session_ref}
    end
  end

  def new!(attrs), do: new(attrs) |> bang()
  def dump(%__MODULE__{} = value), do: Support.dump_struct(value)
  defp bang({:ok, value}), do: value
  defp bang({:error, reason}), do: raise(ArgumentError, Atom.to_string(reason))
end

defmodule AppKit.Core.RuntimeReadback.WorkspaceRef do
  @moduledoc "Workspace identity for public readback DTOs. Raw paths are never exposed."

  alias AppKit.Core.RuntimeReadback.Support

  @enforce_keys [:id, :path_redacted?]
  defstruct [:id, :display_label, :path_redacted?, metadata: %{}]

  def new(%__MODULE__{} = value), do: {:ok, value}

  def new(attrs) when is_binary(attrs), do: new(%{id: attrs, path_redacted?: true})

  def new(attrs) do
    with {:ok, attrs, nil} <- Support.normalize(attrs),
         :ok <- Support.reject_selectors(attrs, :invalid_workspace_ref),
         id when is_binary(id) <- Support.required(attrs, :id),
         true <- Support.safe_ref?(id),
         true <- Support.required(attrs, :path_redacted?),
         label <- Support.optional(attrs, :display_label),
         true <- is_nil(label) or is_binary(label),
         metadata <- Support.optional(attrs, :metadata, %{}),
         true <- is_map(metadata) do
      {:ok, %__MODULE__{id: id, display_label: label, path_redacted?: true, metadata: metadata}}
    else
      _ -> {:error, :invalid_workspace_ref}
    end
  end

  def new!(attrs), do: new(attrs) |> bang()
  def dump(%__MODULE__{} = value), do: Support.dump_struct(value)
  defp bang({:ok, value}), do: value
  defp bang({:error, reason}), do: raise(ArgumentError, Atom.to_string(reason))
end
