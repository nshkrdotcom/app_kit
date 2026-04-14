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
