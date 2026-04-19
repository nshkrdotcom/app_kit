# AppKit Core

Shared northbound surface contracts for the AppKit workspace.

`app_kit_core` owns the frozen northbound DTOs and backend behaviour contracts
that callers depend on before any lower `mezzanine`/bridge details are exposed.

Current contract groups:

- request context and support refs
- paging, sorting, and filtering primitives
- error and action envelopes
- subject, execution, decision, projection, and operator reference DTOs
- installation DTOs, including the operator-only `AuthoringBundleImport`
  envelope for deterministic pack bundle import
- northbound backend behaviours for work queries, reviews, and installations

`AuthoringBundleImport` is intentionally separate from ordinary installation
templates. It carries bundle checksum/signature, manifest/spec echoes,
descriptor metadata, policy refs, and optional expected installation revision;
it rejects platform deployment or migration fields at the AppKit boundary.

`AppKit.Core.Result` and `AppKit.Core.RunRef` remain part of the current
northbound contract set and are not treated as temporary coexistence shims.

Default runtime backend configuration for the surface packages belongs under
the `:app_kit_core` OTP application. The workspace no longer uses a synthetic
`:app_kit` config namespace for surface backends.
