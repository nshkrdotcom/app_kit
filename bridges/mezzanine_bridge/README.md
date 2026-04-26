# AppKit Mezzanine Bridge

`AppKit.Bridges.MezzanineBridge` is the internal adapter layer that binds the
stable `AppKit.Core.*` contract to lower-backed Mezzanine service modules that
live inside this package.

It is an implementation unit inside `app_kit`, not a product-facing dependency
surface.

## Generated Artifact Hygiene

Archival proofs and operator-service trace reconstruction tests must write
runtime bundles under OS temp roots, never under this package directory. The
bridge default cold-store root is `System.tmp_dir!/app_kit_mezzanine_bridge_archival_store`;
per-test archive proofs allocate their own temp subdirectory and clean it with
`on_exit/1`.

Committed fixtures are immutable. If a proof needs mutable archival output, add
a test-owned temp root instead of writing to `tmp/` inside the repo.

## Leased Lower Reads

The bridge projects Mezzanine read and stream-attach leases into AppKit DTOs
with an `authorization_scope` payload. Operator query services must present
that scope back to `Mezzanine.Leasing` before dispatching any lower-facts read,
then pass the tenant-scoped read intent through the Mezzanine Integration
Bridge.

This keeps product-facing AppKit reads northbound while preserving the lower
tenant boundary: a valid lease token alone is insufficient if the caller scope
does not match the tenant, installation, subject, execution, and trace carried
by the lease.

## Runtime Projections

`Mezzanine.AppKitBridge.WorkQueryService.get_subject_projection/3` prefers the
Mezzanine `operator_subject_runtime` projection row when it is present, then
falls back to the legacy work projection. Runtime projection rows expose compact
lower receipt refs, execution dispatch state, token totals, rate-limit status,
runtime event counts, evidence refs, and pending review ids through
`AppKit.WorkSurface.get_projection/3`.

This lookup is ref-driven. The bridge does not read process environment and it
does not accept static provider object selectors for GitHub, Linear, Codex, or
workflow objects.

## Phase-3 Operator Recovery

The bridge exposes the release-readiness operator paths proven in Stack Lab:

- `OperatorQueryService.get_archived_unified_trace_by_pivot/2` reconstructs an
  archived trace from trace, subject, execution, decision, run, attempt,
  artifact, or manifest pivots.
- Unified trace DTOs carry source labels and phase-3 staleness classes so
  operators can distinguish archived truth from hot, lower-fresh, stale
  projection, diagnostic, or unavailable data.
- `OperatorQueryService.subject_status/2` includes lifecycle continuation
  summaries for pending, retry-scheduled, dead-lettered, and completed
  continuations.
- `OperatorActionService.apply_action/2` supports safe `:retry_continuation`
  and `:waive_continuation` actions. Both target one continuation id and
  preserve operator trace metadata.

## Product Boundary

Products should see this bridge only as the configured backend behind AppKit
surfaces. They should not import lower Mezzanine service modules directly for
governed writes or lower reads. `mix app_kit.no_bypass` is the static gate that
keeps product code on the AppKit side of this boundary.

## Authoring Bundle Import

The bridge implements `import_authoring_bundle/3` for
`AppKit.InstallationSurface`. It derives the tenant from
`AppKit.Core.RequestContext`, forwards `AppKit.Core.AuthoringBundleImport` to
`MezzanineConfigRegistry.import_authoring_bundle/2`, and returns an AppKit
installation result containing public bundle, installation, and pack
registration summaries.

The bridge does not expose connector loading, context-adapter code loading, or
platform deployment fields. Those remain rejected by the AppKit DTO and by the
Mezzanine authoring bundle validator before runtime activation.
