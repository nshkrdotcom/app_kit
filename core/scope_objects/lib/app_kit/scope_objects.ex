defmodule AppKit.ScopeObjects do
  @moduledoc """
  Generic host-scope, managed-target, and route-status helpers.
  """

  defmodule HostScope do
    @moduledoc false

    @enforce_keys [:scope_id, :actor_id]
    defstruct [:scope_id, :actor_id, metadata: %{}]

    @type t :: %__MODULE__{
            scope_id: String.t(),
            actor_id: String.t(),
            metadata: map()
          }
  end

  defmodule ManagedTarget do
    @moduledoc false

    @enforce_keys [:target_id, :target_kind]
    defstruct [:target_id, :target_kind, metadata: %{}]

    @type t :: %__MODULE__{
            target_id: String.t(),
            target_kind: atom(),
            metadata: map()
          }
  end

  defmodule RouteStatus do
    @moduledoc false

    @enforce_keys [:route_name, :state]
    defstruct [:route_name, :state, details: %{}]

    @type t :: %__MODULE__{
            route_name: atom(),
            state: atom(),
            details: map()
          }
  end

  @spec host_scope(map() | keyword()) :: {:ok, HostScope.t()} | {:error, atom()}
  def host_scope(attrs) do
    attrs = Map.new(attrs)

    with scope_id when is_binary(scope_id) <- Map.get(attrs, :scope_id),
         actor_id when is_binary(actor_id) <- Map.get(attrs, :actor_id) do
      {:ok,
       %HostScope{
         scope_id: scope_id,
         actor_id: actor_id,
         metadata: Map.get(attrs, :metadata, %{})
       }}
    else
      _ -> {:error, :invalid_host_scope}
    end
  end

  @spec managed_target(map() | keyword()) :: {:ok, ManagedTarget.t()} | {:error, atom()}
  def managed_target(attrs) do
    attrs = Map.new(attrs)

    with target_id when is_binary(target_id) <- Map.get(attrs, :target_id),
         target_kind when is_atom(target_kind) <- Map.get(attrs, :target_kind) do
      {:ok,
       %ManagedTarget{
         target_id: target_id,
         target_kind: target_kind,
         metadata: Map.get(attrs, :metadata, %{})
       }}
    else
      _ -> {:error, :invalid_managed_target}
    end
  end

  @spec route_status(map() | keyword()) :: {:ok, RouteStatus.t()} | {:error, atom()}
  def route_status(attrs) do
    attrs = Map.new(attrs)

    with route_name when is_atom(route_name) <- Map.get(attrs, :route_name),
         state when is_atom(state) <- Map.get(attrs, :state) do
      {:ok,
       %RouteStatus{
         route_name: route_name,
         state: state,
         details: Map.get(attrs, :details, %{})
       }}
    else
      _ -> {:error, :invalid_route_status}
    end
  end
end
