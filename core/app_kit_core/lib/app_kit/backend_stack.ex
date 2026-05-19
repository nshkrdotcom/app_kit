defmodule AppKit.BackendStack do
  @moduledoc """
  Explicit backend selection context for AppKit surfaces.

  Product and host entrypoints can pass this struct through surface options as
  `:backend_stack` or `:app_kit_backend_stack`. The stack is intentionally
  keyed by known backend roles, so runtime backend selection is data carried by
  the request context rather than process-wide application environment.
  """

  @enforce_keys [:backends]
  defstruct [:backends]

  @backend_roles MapSet.new([
                   :installation_backend,
                   :source_backend,
                   :work_backend,
                   :work_query_backend,
                   :review_backend,
                   :operator_backend,
                   :runtime_backend,
                   :headless_backend,
                   :agent_intake_backend,
                   :agent_runtime
                 ])

  @type backend_role ::
          :installation_backend
          | :source_backend
          | :work_backend
          | :work_query_backend
          | :review_backend
          | :operator_backend
          | :runtime_backend
          | :headless_backend
          | :agent_intake_backend
          | :agent_runtime

  @type backend :: term()
  @type t :: %__MODULE__{backends: %{backend_role() => backend()}}

  @spec new(map() | keyword()) :: {:ok, t()} | {:error, {:unknown_backend_role, atom()}}
  def new(backends) when is_map(backends) or is_list(backends) do
    with {:ok, normalized} <- normalize(backends) do
      {:ok, %__MODULE__{backends: normalized}}
    end
  end

  @spec new!(map() | keyword()) :: t()
  def new!(backends) do
    case new(backends) do
      {:ok, stack} -> stack
      {:error, reason} -> raise ArgumentError, message: inspect(reason)
    end
  end

  @spec fetch(t(), backend_role() | atom()) :: {:ok, backend()} | :error
  def fetch(%__MODULE__{backends: backends}, role) when is_atom(role) do
    Map.fetch(backends, role)
  end

  @spec roles() :: [backend_role()]
  def roles do
    @backend_roles
    |> MapSet.to_list()
    |> Enum.sort()
  end

  defp normalize(backends) when is_map(backends) do
    backends
    |> Map.to_list()
    |> normalize_pairs(%{})
  end

  defp normalize(backends) when is_list(backends), do: normalize_pairs(backends, %{})

  defp normalize_pairs([], normalized), do: {:ok, normalized}

  defp normalize_pairs([{role, backend} | rest], normalized) when is_atom(role) do
    if MapSet.member?(@backend_roles, role) do
      normalize_pairs(rest, Map.put(normalized, role, backend))
    else
      {:error, {:unknown_backend_role, role}}
    end
  end

  defp normalize_pairs([{role, _backend} | _rest], _normalized) do
    {:error, {:unknown_backend_role, role}}
  end
end
