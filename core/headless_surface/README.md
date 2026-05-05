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

QC:

```bash
mix test
mix format --check-formatted
mix compile --warnings-as-errors
```
