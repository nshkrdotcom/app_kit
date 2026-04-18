# AppKit Core

Shared northbound surface contracts for the AppKit workspace.

`app_kit_core` owns the frozen northbound DTOs and backend behaviour contracts
that callers depend on before any lower `mezzanine`/bridge details are exposed.

Current contract groups:

- request context and support refs
- paging, sorting, and filtering primitives
- error and action envelopes
- subject, execution, decision, projection, and operator reference DTOs
- installation DTOs
- northbound backend behaviours for work queries, reviews, and installations

`AppKit.Core.Result` and `AppKit.Core.RunRef` remain part of the current
northbound contract set and are not treated as temporary coexistence shims.
