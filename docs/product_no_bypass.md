# AppKit Product No-Bypass

## Boundary

AppKit owns the product-boundary scanner. Product surfaces may call AppKit and product-local public modules only. Direct imports of lower runtimes, lower stores, trace writers, provider SDKs, generated SDKs, database repos, or Temporal clients are violations unless the package is a named store-owner, connector-owner, or runtime-owner scope outside product-surface scanning.

## Verification

Run `mix app_kit.no_bypass.scan --profile product --profile hazmat --include <product source globs>` from this repo. The scanner uses deterministic source traversal and fixed-string checks only; regular-expression APIs are not allowed in scanner code or tests.

## Owner Package Exclusions

A package may be excluded from product-surface scanning only when it owns the local store, connector adapter, or runtime integration being excluded. The package must document its adapter, default tier, durable opt-in, migration or preflight, allowed consumer surface, and redaction guarantees in package-local `docs/persistence.md`.

## Forbidden Product Imports

Product surfaces must not import lower runtime, lower store, trace writer, provider SDK, generated SDK, database repo, object store, or Temporal client modules directly. Add an AppKit surface or lower contract first.
