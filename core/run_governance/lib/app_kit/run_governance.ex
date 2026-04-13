defmodule AppKit.RunGovernance do
  @moduledoc """
  Reusable evidence and decision helpers for governed runs.
  """

  defmodule Evidence do
    @moduledoc """
    Host-visible review evidence descriptor for governed runs.
    """

    @enforce_keys [:kind, :summary]
    defstruct [:kind, :summary, details: %{}]

    @type t :: %__MODULE__{
            kind: atom(),
            summary: String.t(),
            details: map()
          }
  end

  defmodule Decision do
    @moduledoc """
    Host-visible review decision descriptor for governed runs.
    """

    @enforce_keys [:run_id, :state]
    defstruct [:run_id, :state, reason: nil]

    @type state :: :approved | :needs_changes

    @type t :: %__MODULE__{
            run_id: String.t(),
            state: state(),
            reason: String.t() | nil
          }
  end

  @spec evidence(map() | keyword()) :: {:ok, Evidence.t()} | {:error, atom()}
  def evidence(attrs) do
    attrs = Map.new(attrs)

    with kind when is_atom(kind) <- Map.get(attrs, :kind),
         summary when is_binary(summary) <- Map.get(attrs, :summary) do
      {:ok, %Evidence{kind: kind, summary: summary, details: Map.get(attrs, :details, %{})}}
    else
      _ -> {:error, :invalid_evidence}
    end
  end

  @spec decision(map() | keyword()) :: {:ok, Decision.t()} | {:error, atom()}
  def decision(attrs) do
    attrs = Map.new(attrs)
    state = Map.get(attrs, :state)

    with run_id when is_binary(run_id) <- Map.get(attrs, :run_id),
         true <- state in [:approved, :needs_changes] do
      {:ok, %Decision{run_id: run_id, state: state, reason: Map.get(attrs, :reason)}}
    else
      _ -> {:error, :invalid_decision}
    end
  end

  @spec review_state(Evidence.t(), keyword()) :: Decision.state()
  def review_state(%Evidence{} = evidence, opts \\ []) do
    cond do
      Keyword.get(opts, :force_needs_changes, false) -> :needs_changes
      evidence.kind in [:risk_notice, :policy_gap] -> :needs_changes
      true -> :approved
    end
  end
end
