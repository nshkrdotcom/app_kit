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
