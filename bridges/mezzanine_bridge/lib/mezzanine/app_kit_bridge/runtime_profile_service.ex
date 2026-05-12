defmodule Mezzanine.AppKitBridge.RuntimeProfileService do
  @moduledoc false

  alias Mezzanine.Installations

  @type ensure_status :: :unchanged | :updated

  @spec ensure(String.t(), map() | nil) :: {:ok, ensure_status()} | {:error, term()}
  def ensure(tenant_id, runtime_profile) do
    with {:ok, result} <- Installations.ensure_runtime_profile(tenant_id, runtime_profile) do
      {:ok, result.status}
    end
  end

  @spec apply(String.t(), map() | nil) :: {:ok, map()} | {:error, term()}
  def apply(tenant_id, runtime_profile) do
    with {:ok, result} <- Installations.ensure_runtime_profile(tenant_id, runtime_profile) do
      {:ok,
       %{
         status: result.status,
         profile_ref: profile_ref(result),
         program_ref: record_ref("program", result.program),
         policy_bundle_ref: record_ref("policy-bundle", result.policy_bundle),
         work_class_ref: record_ref("work-class", result.work_class),
         placement_profile_ref: record_ref("placement-profile", result.placement_profile),
         metadata: %{
           "runtime_profile_applied?" => not is_nil(runtime_profile),
           "program_slug" => record_field(result.program, :slug),
           "work_class_name" => record_field(result.work_class, :name),
           "placement_profile_id" => record_field(result.placement_profile, :profile_id)
         }
       }}
    end
  end

  defp profile_ref(%{program: nil}), do: nil

  defp profile_ref(result) do
    slug = record_field(result.program, :slug) || "runtime"
    "runtime-profile://#{slug}"
  end

  defp record_ref(_kind, nil), do: nil

  defp record_ref(kind, record) do
    case record_field(record, :id) do
      nil -> nil
      id -> "#{kind}://#{id}"
    end
  end

  defp record_field(nil, _key), do: nil
  defp record_field(%_{} = record, key), do: record |> Map.from_struct() |> record_field(key)

  defp record_field(%{} = record, key),
    do: Map.get(record, key) || Map.get(record, Atom.to_string(key))
end
