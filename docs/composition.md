# Composition

AppKit composes lower layers without swallowing their ownership:

- `outer_brain` remains the semantic runtime
- `jido_domain` remains the typed capability and route boundary
- Citadel remains the policy kernel
- `jido_integration` remains the durable lower truth owner
- `ground_plane` remains primitive and lower-level
- `execution_plane` stays behind gateways instead of becoming a public app API

The bridge packages in this workspace keep those seams explicit and app-safe.
