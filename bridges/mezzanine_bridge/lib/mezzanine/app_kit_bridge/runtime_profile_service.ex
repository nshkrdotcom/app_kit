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
end
