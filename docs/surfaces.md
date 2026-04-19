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
