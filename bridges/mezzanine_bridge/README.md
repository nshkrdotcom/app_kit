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
