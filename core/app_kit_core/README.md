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
- product-fabric DTOs for tenant switching, product certification,
  no-bypass scan evidence, and full product fabric smoke proof
- revision/epoch and lease-revocation DTOs for operator-visible fencing and
  revocation evidence
- resource-pressure and retry-posture DTOs for operator-visible shedding,
  retry, and dead-letter evidence
- northbound backend behaviours for work queries, reviews, and installations

`AuthoringBundleImport` is intentionally separate from ordinary installation
templates. It carries bundle checksum/signature, manifest/spec echoes,
descriptor metadata, policy refs, and optional expected installation revision;
it rejects platform deployment or migration fields at the AppKit boundary.

`ProductTenantContext`, `ProductCertification`, `ProductBoundaryNoBypassScan`,
and `FullProductFabricSmoke` are the Phase 4 product fabric contracts. They
require tenant, installation, authority, idempotency, trace, release-manifest,
and principal-or-system-actor scope before a product can claim tenant-switch,
certification, no-bypass, or cross-product smoke evidence.

`InstallationRevisionEpochFence` and `LeaseRevocationEvidence` are the Phase 4
operator projection DTOs for revision fencing and lease revocation. They carry
tenant, installation, authority, idempotency, trace, release-manifest,
principal-or-system-actor scope plus the exact revision, epoch, fence,
revocation, cache invalidation, and post-revocation attempt refs needed for
operator-visible fail-closed evidence.

`QueuePressureProjection` and `RetryPostureProjection` are the Phase 4
operator projection DTOs for resource budget and retry posture evidence. They
carry tenant, installation, authority, idempotency, trace, release-manifest,
principal-or-system-actor scope plus queue/budget/pressure/shed fields or
operation/retry/backoff/idempotency/dead-letter fields so AppKit can render
backpressure and retry state without importing lower-truth modules or runtime
SDK structs.

`AppKit.Core.Result` and `AppKit.Core.RunRef` remain part of the current
northbound contract set and are not treated as temporary coexistence shims.

Default runtime backend configuration for the surface packages belongs under
the `:app_kit_core` OTP application. The workspace no longer uses a synthetic
`:app_kit` config namespace for surface backends.
