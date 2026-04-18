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
