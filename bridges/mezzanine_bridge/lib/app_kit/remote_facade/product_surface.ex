defmodule AppKit.RemoteFacade.ProductSurface do
  @moduledoc """
  AppKit-owned distributed product surface facade.

  Product probes call this facade in distributed StackLab profiles. The facade
  validates the product envelope, then delegates governed work to Mezzanine
  through the caller-owned Mezzanine bridge transport.
  """

  alias AppKit.Bridges.MezzanineBridge.Transport.RuntimeDeps

  @owner_group {__MODULE__, :product_surface}
  @required_fields ~w(
    schema_ref
    tenant_ref
    correlation_ref
    idempotency_key
    trace_ref
    payload_mode
    redaction_class
  )

  @spec owner_group() :: {module(), :product_surface}
  def owner_group, do: @owner_group

  @spec submit_work(map(), keyword()) :: {:ok, map()} | {:error, map()}
  def submit_work(request, opts \\ []) when is_map(request) and is_list(opts) do
    with :ok <- validate_envelope(request),
         {:ok, deps} <- RuntimeDeps.new(opts) do
      RuntimeDeps.submit_work(deps, request, opts)
    end
  end

  @spec readback(String.t(), keyword()) :: {:ok, map()} | {:error, map()}
  def readback(ref, opts \\ []) when is_binary(ref) and is_list(opts) do
    with :ok <- validate_ref(ref),
         {:ok, deps} <- RuntimeDeps.new(opts) do
      RuntimeDeps.readback(deps, ref, opts)
    end
  end

  defp validate_envelope(request) do
    case Enum.find(@required_fields, &(string_value(request, &1) == nil)) do
      nil -> validate_payload_mode(request)
      field -> {:error, error(:invalid_envelope, %{"missing_field" => field})}
    end
  end

  defp validate_payload_mode(request) do
    case string_value(request, "payload_mode") do
      mode when mode in ["refs_only", "bounded_summary", "claim_check"] ->
        :ok

      _other ->
        {:error, error(:payload_not_allowed)}
    end
  end

  defp validate_ref(ref) do
    if String.trim(ref) == "" do
      {:error, error(:invalid_envelope, %{"missing_field" => "ref"})}
    else
      :ok
    end
  end

  defp string_value(map, field) do
    value = Map.get(map, field) || Map.get(map, String.to_atom(field))

    if is_binary(value) and String.trim(value) != "" do
      value
    end
  end

  defp error(code, attrs \\ %{}) do
    Map.merge(
      %{
        "code" => Atom.to_string(code),
        "owner" => "app_kit",
        "facade" => "product_surface"
      },
      attrs
    )
  end
end
