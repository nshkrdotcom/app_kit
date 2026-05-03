# Operator Surface

Operator-facing composition around review and projection reads.

The public `AppKit.OperatorSurface` surface stays stable while projection and
review behavior can be resolved through a backend module.

Default backend leases include authorization scope for downstream lower-backed
operator reads. Bridge backends must preserve that scope in `ReadLease` and
`StreamAttachLease` DTOs so Mezzanine can fail closed on tenant, installation,
subject, execution, or trace mismatch before any lower-facts read is attempted.

Standalone backends can be read from `config :app_kit_core, :operator_backend,
...`. Governed calls ignore that fallback when `:governed?` or authority-ref
options are present; callers must pass `:operator_backend` directly or use the
compiled default backend. Products should not configure a synthetic `:app_kit`
application or use process config as authority.

## Phase 4 projection contracts

Operator-visible projections that cross product or control-room boundaries use
`AppKit.Core.OperatorSurfaceProjection`. The DTO requires tenant,
installation, operator, target, authority, permission-decision, idempotency,
trace, correlation, release-manifest, projection-version, source-event-position,
dispatch-state, workflow-effect-state, and `staleness_class` fields. This keeps
local acceptance, queued signal dispatch, Temporal delivery, pending workflow
acknowledgement, processed effect, failed dispatch, and stale projection states
distinct without exposing Temporal SDK objects to AppKit consumers.

Observer descriptors use `AppKit.Core.ObserverDescriptor`. They carry explicit
redaction policy, allow-listed fields, blocked fields, tenant scope, and
authority evidence so product and operator readers never receive raw provider
metadata or cross-tenant lower truth through observer projections.
