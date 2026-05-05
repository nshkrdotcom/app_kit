# AppKit Headless Surface

Phase 12 package for AgentIntake, status, readback, cancel, and
HTTP-accessible headless endpoint contracts.

The surface accepts authority refs and command refs only. It never accepts raw
credential material, provider payloads, target credentials, local auth files,
or unmanaged runtime configuration.

QC:

```bash
mix test
mix format --check-formatted
mix compile --warnings-as-errors
```
