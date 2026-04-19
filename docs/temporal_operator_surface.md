# Temporal Operator Surface Boundary

## Position

AppKit does not own the Temporal runtime and should not import a Temporal SDK directly.

Mezzanine owns the durable workflow boundary and the native local Temporal developer substrate. AppKit consumes workflow state through governed Mezzanine/AppKit seams and operator projections.

## Local development

When AppKit work needs live workflow state, start the Mezzanine-owned substrate:

```bash
cd /home/home/p/g/n/mezzanine
just dev-up
just dev-status
just temporal-ui
```

Expected contract:

- Temporal frontend: `127.0.0.1:7233`
- Temporal UI: `http://127.0.0.1:8233`
- Namespace: `default`
- Service: `mezzanine-temporal-dev.service`
- State: `~/.local/share/temporal/dev-server.db`

## Boundary rules

- AppKit operator surfaces may display workflow-derived state.
- AppKit should read workflow state from Mezzanine projections or explicit Mezzanine facades.
- AppKit should not start, signal, cancel, or query Temporal workflows by calling Temporal directly.
- AppKit should not own Temporal worker supervision.
- AppKit should not invent a separate Temporal dev service.

## Operator-facing responsibilities

AppKit should make Temporal-backed work understandable to operators without leaking runtime internals as product APIs.

Operator views should expose:

- stable workflow identity supplied by Mezzanine,
- lifecycle state and staleness labels,
- signal/cancel actions routed through governed seams,
- lineage links to lower runs, attempts, artifacts, reviews, and evidence,
- failure classes and safe recovery actions.

## Development rule

If an AppKit change appears to need a Temporal SDK call, first define or extend the Mezzanine/AppKit seam. Direct Temporal coupling in AppKit is a design smell unless a later architecture decision explicitly changes ownership.
