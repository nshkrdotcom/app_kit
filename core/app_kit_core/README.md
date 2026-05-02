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
- platform error-taxonomy DTOs for operator-visible error class, retry posture,
  safe action, redaction, and runbook evidence
- archival restore DTOs for cold-index trace restore, artifact restore,
  hot/cold conflict quarantine, and archival sweep retry evidence
- evidence/audit DTOs for Citadel audit hash-chain projection and Mezzanine
  suppression visibility projection
- runtime projection DTOs for source binding, workspace, execution, lower
  receipt, evidence, review, operator-command, and runtime-event facts
- extension supply-chain DTOs for pack integrity posture, pack bundle schema,
  and connector-admission projection
- northbound backend behaviours for work queries, reviews, and installations

`AuthoringBundleImport` is intentionally separate from ordinary installation
templates. It carries bundle checksum/schema posture, manifest/spec echoes,
descriptor metadata, policy refs, and optional expected installation revision;
it rejects platform deployment or migration fields at the AppKit boundary.
`AuthoringBundleImport.checksum_for/1` canonicalizes the import payload and
returns the `sha256:` checksum products use before import.
Authoring bundles are verified by checksum/schema validation in v1 unless
Phase 1 source-verifies signing/signature-verification modules and tests or
Phase 7 implements signing. Signature verification is a post-v1/new-contract
candidate until then.

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

`ErrorTaxonomyProjection` is the Phase 4 northbound mirror for
`Platform.ErrorTaxonomy.v1`. It carries owner, producer, consumer, error code,
error class, retry posture, safe action, redaction class, runbook, tenant,
authority, idempotency, trace, and release-manifest refs so AppKit can render
operator-safe error handling without importing Citadel authority internals.

`ColdRestoreTraceProjection`, `ColdRestoreArtifactProjection`,
`ArchivalConflictProjection`, and `ArchivalSweepProjection` are the Phase 4
operator projection DTOs for archival restore and cold-index evidence. They
preserve AppKit as a read-only projection consumer of Mezzanine archival truth
while carrying the tenant, authority, trace, release-manifest, source-contract,
hash, precedence, quarantine, and retry fields needed for incident export and
restore operator flows.

`AuditHashChainProjection` and `SuppressionVisibilityProjection` are the Phase
4 operator projection DTOs for immutable audit evidence and suppression
visibility. They preserve AppKit as a read-only projection consumer while
carrying tenant, authority, trace, release-manifest, source-contract,
hash-chain, diagnostics, and recovery-action fields required for incident
reconstruction.

`ExtensionPackSignatureProjection`, `ExtensionPackBundleProjection`, and
`ConnectorAdmissionProjection` are contract-only product/operator projection
DTOs for extension supply-chain evidence until their owning executable proofs
are green. They preserve AppKit as a read-only consumer of Mezzanine pack
authoring truth and Jido Integration connector admission truth while carrying
tenant, authority, trace, release-manifest, source-contract, integrity posture,
schema, declared-resource, connector, and duplicate admission fields needed for
product registry views.

`SubjectRuntimeProjection` and its nested runtime DTOs are the typed coding-ops
operator projection contract. They carry only refs and reducer facts that come
from source admission, workflow state, lower receipts, durable decision ids, and
explicit operator commands. The DTO boundary rejects static provider object
selectors such as GitHub issue numbers, Linear issue ids, PR numbers, Codex
session ids, and workflow ids because those identifiers must be discovered or
carried by lower receipts before they can appear in an operator projection.

`AppKit.Core.Result` and `AppKit.Core.RunRef` remain part of the current
northbound contract set and are not treated as temporary coexistence shims.

Default runtime backend configuration for the surface packages belongs under
the `:app_kit_core` OTP application. The workspace no longer uses a synthetic
`:app_kit` config namespace for surface backends.
