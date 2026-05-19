defmodule AppKit.Bridges.MezzanineBridge.SourceAdapter do
  @moduledoc """
  Source backend adapter for the Mezzanine bridge.

  The adapter owns source-service lookup and source callback error normalization
  so the public bridge facade can remain a stable delegation surface.
  """

  @behaviour AppKit.Core.Backends.SourceBackend

  alias AppKit.Bridges.MezzanineBridge.{Errors, Services}
  alias AppKit.Core.RequestContext

  @impl true
  def sync_source(%RequestContext{} = context, source_role_ref, source_page, opts)
      when (is_atom(source_role_ref) or is_binary(source_role_ref)) and is_map(source_page) and
             is_list(opts) do
    case Services.source(opts).sync_source(context, source_role_ref, source_page, opts) do
      {:ok, result} -> {:ok, result}
      {:error, reason} -> Errors.normalize(reason)
    end
  end

  @impl true
  def current_states(%RequestContext{} = context, source_role_ref, request, opts)
      when (is_atom(source_role_ref) or is_binary(source_role_ref)) and is_map(request) and
             is_list(opts) do
    service = Services.source(opts)

    if Services.exports?(service, :current_states, 4) do
      case service.current_states(context, source_role_ref, request, opts) do
        {:ok, result} -> {:ok, result}
        {:error, reason} -> Errors.normalize(reason)
      end
    else
      Errors.normalize(:source_current_state_not_configured)
    end
  end

  @impl true
  def fetch_candidates(%RequestContext{} = context, source_role_ref, request, opts)
      when (is_atom(source_role_ref) or is_binary(source_role_ref)) and is_map(request) and
             is_list(opts) do
    service = Services.source(opts)

    if Services.exports?(service, :fetch_candidates, 4) do
      case service.fetch_candidates(context, source_role_ref, request, opts) do
        {:ok, result} -> {:ok, result}
        {:error, reason} -> Errors.normalize(reason)
      end
    else
      Errors.normalize(:source_candidate_fetch_not_configured)
    end
  end

  @impl true
  def publish_source(%RequestContext{} = context, publication_role_ref, request, opts)
      when (is_atom(publication_role_ref) or is_binary(publication_role_ref)) and
             is_map(request) and is_list(opts) do
    service = Services.source(opts)

    if Services.exports?(service, :publish_source, 4) do
      case service.publish_source(context, publication_role_ref, request, opts) do
        {:ok, result} -> {:ok, result}
        {:error, reason} -> Errors.normalize(reason)
      end
    else
      Errors.normalize(:source_publication_not_configured)
    end
  end
end
