defmodule AppKit.EvolutionSurface do
  @moduledoc "Product/operator-safe surface for Chassis Evolution readback and consent."

  def list_evolution_batches(_ctx, _params, _opts \\ []),
    do: {:error, {:not_implemented, __MODULE__}}

  def get_evolution_status(_ctx, _params, _opts \\ []),
    do: {:error, {:not_implemented, __MODULE__}}

  def record_operator_consent(_ctx, _params, _opts \\ []),
    do: {:error, {:not_implemented, __MODULE__}}

  def get_candidate_diff(_ctx, _params, _opts \\ []),
    do: {:error, {:not_implemented, __MODULE__}}
end

defmodule AppKit.EvolutionSurface.Backend.Local do
  @moduledoc "Local Chassis Evolution backend."
  def handle(_request, _opts), do: {:error, {:not_implemented, __MODULE__}}
end

defmodule AppKit.EvolutionSurface.Backend.Boundary do
  @moduledoc "Boundary-backed Chassis Evolution surface."
  def handle(_request, _opts), do: {:error, {:not_implemented, __MODULE__}}
end

defmodule AppKit.EvolutionSurface.Backend.Standalone do
  @moduledoc "Standalone Chassis Evolution surface fallback."
  def handle(_request, _opts), do: {:error, {:not_implemented, __MODULE__}}
end

defmodule AppKit.Core.Evolution.DTO.BatchSummary do
  @moduledoc "Product-safe Chassis Evolution batch summary."
  defstruct [:failure_batch_ref, :tenant_ref, :summary, :redaction_posture]
end

defmodule AppKit.Core.Evolution.DTO.CandidateSummary do
  @moduledoc "Product-safe Chassis Evolution candidate summary."
  defstruct [:candidate_ref, :state, :score_matrix_ref, :diff_ref]
end

defmodule AppKit.EvolutionSurface.RedactedDiffRef do
  @moduledoc "Reference to lower-read diff material."
  defstruct [:diff_ref, :lower_read_lease_ref]
end
