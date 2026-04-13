# Composition

AppKit composes lower layers without swallowing their ownership:

- `outer_brain` remains the semantic runtime
- `jido_domain` remains the typed capability and route boundary
- Citadel remains the policy kernel
- `jido_integration` remains the durable lower truth owner
- `ground_plane` remains primitive and lower-level
- `execution_plane` stays behind gateways instead of becoming a public app API

The bridge packages in this workspace keep those seams explicit and app-safe.

## Current Host Paths

The assembled host-facing paths are now split cleanly:

- typed host path:
  `reference_host -> AppKit.DomainSurface -> AppKit.Bridges.DomainBridge -> Jido.Domain -> Citadel.HostIngress -> jido_integration`
- semantic host path:
  `reference_host -> AppKit.ConversationBridge -> AppKit.Bridges.OuterBrainBridge -> OuterBrain -> Jido.Domain -> Citadel.HostIngress -> jido_integration`

That split is deliberate:

- `DomainSurface` is the typed application boundary for explicit domain command
  and query dispatch
- `ConversationBridge` is the semantic application boundary for turn-oriented
  interaction
- `DomainBridge` and `OuterBrainBridge` stay thin and translate only between
  app-safe inputs and the lower owner seams
- `reference_host` proves both paths against the real lower stack instead of
  faking the kernel or the durable Spine
