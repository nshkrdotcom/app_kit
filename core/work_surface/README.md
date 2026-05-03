# AppKit Work Surface

`AppKit.WorkSurface` is the app-facing typed surface for governed-object intake,
queue reads, detail reads, named projections, and reducer-owned runtime
projections.

In Phase `3.2` it defaults to `AppKit.Bridges.MezzanineBridge`, which keeps the
public contract in `app_kit_core` while routing the lower implementation through
the internal app-kit mezzanine bridge service layer.

Standalone query backends can be read from `config :app_kit_core,
:work_query_backend, ...`. Governed calls ignore that fallback when `:governed?`
or authority-ref options are present; callers must pass `:work_query_backend`
directly or use the compiled default bridge.

Use `get_runtime_projection/3` for the coding-ops operator runtime view. The
result is `AppKit.Core.SubjectRuntimeProjection`, assembled from source refs,
workspace refs, workflow state, lower receipt refs, evidence refs, durable
review decisions, runtime facts, and available operator commands. Products
should keep generic `get_projection/3` calls for named legacy projections and
should not pass process-env or static provider-object selectors into runtime
reads.
