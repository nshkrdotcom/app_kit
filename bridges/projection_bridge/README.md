# Projection Bridge

App-facing bridge for read-model projections and operator views.

Phase 7 projection bridge payloads include memory-default persistence posture
evidence and preserve AppKit as a read-only projection consumer. The bridge
does not persist raw prompt bodies, provider payload bodies, auth material, or
provider account secrets, and debug tap failure cannot mutate projection
payload state.

## Persistence Documentation

See `docs/persistence.md` for tiers, defaults, adapters, unsupported selections, config examples, restart claims, durability claims, debug sidecar behavior, redaction guarantees, migration or preflight behavior, and no-bypass scope when applicable.
