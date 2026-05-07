# AppKit Headless Surface

Phase 12 package for AgentIntake, status, readback, cancel, and
HTTP-accessible headless endpoint contracts.

The surface accepts authority refs and command refs only. It never accepts raw
credential material, provider payloads, target credentials, local auth files,
or unmanaged runtime configuration.

Phase 14 submit DTOs carry the handoff-critical credential handle,
credential lease, native-auth assertion, target attach, trace, operation, and
idempotency refs so product ingress cannot resume a headless session from raw
provider or target material.

Phase 7 headless projection/readback contracts carry
`AppKit.Core.PersistencePosture` evidence. The default profile is memory/
ref-only; retained projection state is optional and can be selected `:off`
without blocking status, cancel, readback, or provider-effect flow.

QC:

```bash
mix test
mix format --check-formatted
mix compile --warnings-as-errors
```

## Persistence Documentation

See `docs/persistence.md` for tiers, defaults, adapters, unsupported selections, config examples, restart claims, durability claims, debug sidecar behavior, redaction guarantees, migration or preflight behavior, and no-bypass scope when applicable.
