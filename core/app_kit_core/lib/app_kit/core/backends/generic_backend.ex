defmodule AppKit.Core.Backends.GenericBackend do
  @moduledoc """
  Generic AppKit backend contract for role-based product calls.
  """

  alias AppKit.Core.{Context, RequestContext, SurfaceError}

  @type context :: Context.t() | RequestContext.t()

  @callback sync_source(context(), term(), map(), keyword()) ::
              {:ok, term()} | {:error, SurfaceError.t()}
  @callback fetch_candidates(context(), term(), map(), keyword()) ::
              {:ok, term()} | {:error, SurfaceError.t()}
  @callback current_states(context(), term(), map(), keyword()) ::
              {:ok, term()} | {:error, SurfaceError.t()}
  @callback publish(context(), term(), map(), keyword()) ::
              {:ok, term()} | {:error, SurfaceError.t()}
  @callback execute_operation(context(), term(), term(), map(), keyword()) ::
              {:ok, term()} | {:error, SurfaceError.t()}
  @callback submit_work(context(), map(), keyword()) ::
              {:ok, term()} | {:error, SurfaceError.t()}
  @callback invoke_runtime_operation(context(), term(), term(), map(), keyword()) ::
              {:ok, term()} | {:error, SurfaceError.t()}
  @callback invoke_runtime_tool(context(), term(), term(), map(), keyword()) ::
              {:ok, term()} | {:error, SurfaceError.t()}
  @callback collect_evidence(context(), term(), map(), keyword()) ::
              {:ok, term()} | {:error, SurfaceError.t()}
  @callback invoke_resource_effect(context(), term(), map(), keyword()) ::
              {:ok, term()} | {:error, SurfaceError.t()}
  @callback open_review(context(), term(), map(), keyword()) ::
              {:ok, term()} | {:error, SurfaceError.t()}
  @callback submit_review_decision(context(), term(), map(), keyword()) ::
              {:ok, term()} | {:error, SurfaceError.t()}
  @callback get_projection(context(), map(), keyword()) ::
              {:ok, term()} | {:error, SurfaceError.t()}
  @callback lookup_trace(context(), term(), keyword()) ::
              {:ok, term()} | {:error, SurfaceError.t()}
  @callback replay_trace(context(), term(), keyword()) ::
              {:ok, term()} | {:error, SurfaceError.t()}
  @callback request_lower_read(context(), term(), term(), keyword()) ::
              {:ok, term()} | {:error, SurfaceError.t()}

  @optional_callbacks sync_source: 4,
                      fetch_candidates: 4,
                      current_states: 4,
                      publish: 4,
                      execute_operation: 5,
                      submit_work: 3,
                      invoke_runtime_operation: 5,
                      invoke_runtime_tool: 5,
                      collect_evidence: 4,
                      invoke_resource_effect: 4,
                      open_review: 4,
                      submit_review_decision: 4,
                      get_projection: 3,
                      lookup_trace: 3,
                      replay_trace: 3,
                      request_lower_read: 4
end

defmodule AppKit.Core.GenericSurfaceSupport do
  @moduledoc false

  alias AppKit.Core.{GenericBuilder, SurfaceError}

  @spec dispatch(keyword(), atom(), atom(), [term()]) ::
          {:ok, term()} | {:error, SurfaceError.t()}
  def dispatch(opts, backend_key, callback, args) when is_list(opts) do
    with :ok <- reject_forbidden_args(args),
         {:ok, backend} <- fetch_backend(opts, backend_key),
         :ok <- ensure_callback(backend, callback, length(args) + 1) do
      apply(backend, callback, args ++ [opts])
    else
      {:error, %SurfaceError{} = error} -> {:error, error}
      {:error, reason} -> fail_closed(callback, reason)
    end
  end

  defp fetch_backend(opts, backend_key) do
    case Keyword.fetch(opts, backend_key) do
      {:ok, backend} -> {:ok, backend}
      :error -> {:error, :generic_backend_not_configured}
    end
  end

  defp ensure_callback(backend, callback, arity) do
    with {:module, ^backend} <- Code.ensure_loaded(backend),
         true <- function_exported?(backend, callback, arity) do
      :ok
    else
      false -> {:error, {:unsupported_generic_callback, callback, arity}}
      {:error, reason} -> {:error, {:backend_not_loaded, backend, reason}}
    end
  end

  defp reject_forbidden_args(args) do
    args
    |> Enum.find_value(:ok, fn
      attrs when is_map(attrs) ->
        case GenericBuilder.reject_forbidden_fields(attrs) do
          :ok -> false
          {:error, reason} -> {:error, reason}
        end

      _arg ->
        false
    end)
  end

  defp fail_closed(callback, reason) do
    {:ok, error} =
      SurfaceError.new(%{
        code: "generic_app_kit_surface_not_ready",
        message: "Generic AppKit surface is not connected to a backend",
        kind: :boundary,
        retryable: false,
        details: %{callback: callback, reason: reason}
      })

    {:error, error}
  end
end
