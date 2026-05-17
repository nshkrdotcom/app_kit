defmodule AppKit.Core.SourceSyncRequest do
  @moduledoc "Generic source synchronization request."
  use AppKit.Core.GenericStruct,
    required: [:request_ref, :source_role_ref, :payload],
    optional: [:cursor_ref, metadata: %{}]
end

defmodule AppKit.Core.SourceCandidateRequest do
  @moduledoc "Generic source candidate request."
  use AppKit.Core.GenericStruct,
    required: [:request_ref, :source_role_ref, :query],
    optional: [:cursor_ref, :page_size, filters: %{}, metadata: %{}]
end

defmodule AppKit.Core.SourceCurrentStateRequest do
  @moduledoc "Generic source current-state request."
  use AppKit.Core.GenericStruct,
    required: [:request_ref, :source_role_ref, :source_object_refs],
    optional: [metadata: %{}],
    validate: [&__MODULE__.validate_source_object_refs/1]

  @doc false
  def validate_source_object_refs(%{source_object_refs: refs}) when is_list(refs), do: :ok
  def validate_source_object_refs(_attrs), do: {:error, :invalid_source_object_refs}
end

defmodule AppKit.Core.SourcePublicationRequest do
  @moduledoc "Generic source publication request."
  use AppKit.Core.GenericStruct,
    required: [:request_ref, :publication_role_ref, :source_ref, :subject_ref, :body_ref],
    optional: [preview?: false, metadata: %{}]
end

defmodule AppKit.Core.WorkSubmitRequest do
  @moduledoc "Generic work submission request."
  use AppKit.Core.GenericStruct,
    required: [:request_ref, :work_role_ref, :target_ref, :payload],
    optional: [:workflow_role_ref, metadata: %{}]
end

defmodule AppKit.Core.RuntimeOperationRequest do
  @moduledoc "Generic runtime operation request."
  use AppKit.Core.GenericStruct,
    required: [:request_ref, :runtime_role_ref, :operation_role_ref, :input_ref],
    optional: [:session_ref, :continuation_ref, metadata: %{}]
end

defmodule AppKit.Core.ToolInvocationRequest do
  @moduledoc "Generic runtime tool invocation request."
  use AppKit.Core.GenericStruct,
    required: [:request_ref, :tool_role_ref, :operation_role_ref, :input_ref],
    optional: [:runtime_session_ref, metadata: %{}]
end

defmodule AppKit.Core.EvidenceCollectionRequest do
  @moduledoc "Generic evidence collection request."
  use AppKit.Core.GenericStruct,
    required: [:request_ref, :evidence_role_ref, :subject_ref],
    optional: [artifact_refs: [], revision_refs: [], metadata: %{}]
end

defmodule AppKit.Core.ResourceEffectInvocationRequest do
  @moduledoc "Generic resource-effect request."
  use AppKit.Core.GenericStruct,
    required: [:request_ref, :resource_effect_role_ref, :subject_ref],
    optional: [confirm?: false, operation_group_ref: nil, metadata: %{}]
end

defmodule AppKit.Core.ReviewRequest do
  @moduledoc "Generic review request."
  use AppKit.Core.GenericStruct,
    required: [:request_ref, :review_role_ref, :subject_ref],
    optional: [:decision_ref, :decision, :reason_ref, metadata: %{}]
end

defmodule AppKit.Core.TraceRequest do
  @moduledoc "Generic trace lookup/replay/export request."
  use AppKit.Core.GenericStruct,
    required: [:request_ref, :trace_ref],
    optional: [:redaction_policy_ref, metadata: %{}]
end

defmodule AppKit.Core.ProjectionRequest do
  @moduledoc "Generic projection request."
  use AppKit.Core.GenericStruct,
    required: [:request_ref, :subject_ref, :projection_kind],
    optional: [:projection_ref, metadata: %{}]
end

defmodule AppKit.Core.LeaseRequest do
  @moduledoc "Generic lower-read or stream-attach lease request."
  use AppKit.Core.GenericStruct,
    required: [:request_ref, :subject_ref, :scope],
    optional: [:lease_ref, metadata: %{}]
end
