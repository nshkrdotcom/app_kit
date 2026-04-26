# Surfaces

AppKit exposes seven main surface families:

- `ChatSurface` for chat-oriented host ingress above `outer_brain`
- `DomainSurface` for typed host ingress above `citadel_domain_surface`
- `OperatorSurface` for review and status reads above lower durable truth
- `WorkControl` for governed-run creation and work submission
- `RunGovernance` for evidence and decision shaping
- `RuntimeGateway` for app-facing runtime gateway descriptors
- `ConversationBridge` for follow-up and live-update bridging

These surfaces are intentionally reusable and app-facing. They are not a second
policy kernel and not a second lower control plane.

## Product Boundary

Products consume these surfaces instead of lower repos. Governed writes,
reviews, installation lifecycle, operator actions, trace lookup, semantic assist,
and lower-backed reads all enter through AppKit and then move through the owning
lower layer.

`mix app_kit.no_bypass` enforces this split. The `product` profile rejects direct
product imports into lower governed-write APIs while allowing pure
`Mezzanine.Pack` authoring. The `hazmat` profile rejects direct Execution Plane
usage so the execution layer cannot become a product API.

Default surface backends are configured under `:app_kit_core`. The config keys
match the surface families: `:installation_backend`, `:work_query_backend`,
`:review_backend`, `:operator_backend`, and `:work_backend`.

`WorkSurface.get_runtime_projection/3` is the typed runtime read for
coding-ops operator views. It returns `AppKit.Core.SubjectRuntimeProjection`
instead of a generic projection map, so products consume source bindings,
workspace refs, execution state, lower receipts, evidence, review decisions,
runtime events, and operator commands without importing lower Mezzanine or Jido
modules. Runtime projection identity must already be present in source
admission, workflow state, lower receipts, reducer rows, or explicit operator
DTOs; products must not provide process-env selectors or static provider object
ids to locate runtime state.

## Operator Projection Contracts

Phase 4 operator projections are staleness-aware. Use
`AppKit.Core.OperatorSurfaceProjection` when exposing control-room projection
state across a product/operator boundary, and use
`AppKit.Core.ObserverDescriptor` when exposing observer metadata. Both DTOs
require tenant, authority, idempotency, trace, release-manifest, and redaction
evidence so UI code can distinguish queued local intent from delivered signals,
pending workflow acknowledgements, processed effects, failed dispatches, stale
projections, and diagnostic-only observer data.

## Schema Registry

Generated BFF and SDK shapes are recorded by
`AppKit.Workspace.SchemaRegistry`. The Phase 4 registry declares
`AppKit.ProductBootstrap.v1`, `AppKit.SchemaRegistryEntry.v1`, and
`Platform.GeneratedArtifactOwnership.v1` with owner repo, producers,
consumers, required enterprise envelope fields, runbooks, proofs, and
release-manifest keys.

Boundary generation is deterministic: `mix app_kit.gen.boundary <schema_name>`
writes DTO, mapper, mapper-test, and generated-artifact manifest files. The
manifest records artifact hashes so product packages can prove they are using
AppKit-owned generated shapes rather than hand-edited DTOs or lower-truth
imports.
