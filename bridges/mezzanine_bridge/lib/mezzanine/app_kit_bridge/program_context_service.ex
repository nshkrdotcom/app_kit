defmodule Mezzanine.AppKitBridge.ProgramContextService do
  @moduledoc """
  Resolves durable routing identifiers from product-owned metadata.

  App-facing callers should not need to carry lower `program_id` and
  `work_class_id` values just to use the typed `app_kit` surfaces. This
  service keeps that lookup inside the lower bridge seam.
  """

  alias Mezzanine.AppKitBridge.AdapterSupport
  alias Mezzanine.Installations

  @spec resolve(String.t(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  def resolve(tenant_id, attrs, opts \\ [])
      when is_binary(tenant_id) and is_map(attrs) and is_list(opts) do
    case Installations.resolve_program_context(tenant_id, attrs, opts) do
      {:ok, context} -> {:ok, context}
      {:error, reason} -> {:error, AdapterSupport.normalize_error(reason)}
    end
  end
end
