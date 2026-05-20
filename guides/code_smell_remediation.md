# AppKit Code Smell Remediation

This guide records the repo-local implementation posture after the GN-TEN code
smell remediation pass. It is the README-linked summary for maintainers; the
full phase evidence lives in the cross-repo code-smell packet.

## What Changed

- Bridge behavior is characterized with contract tests before adapter changes.
- Mezzanine bridge responsibilities are separated so AppKit remains the
  northbound product surface instead of a lower-stack god adapter.
- Backend selection now threads through explicit context instead of hidden
  application-env fallback.
- DTO surfaces are split by role so product callers consume narrower, stable
  structs.
- Build-support dynamic evaluation is bounded and documented as build tooling,
  not runtime behavior.

## Maintainer Rules

- Product code should enter lower stack behavior through AppKit surfaces.
- Backend selection belongs in explicit context or bridge configuration.
- Do not add new provider-specific dispatch below the product/adapter zone.
- Do not introduce Regex, unsafe dynamic atoms, unsupervised processes, or
  hidden mutable runtime configuration in touched packages.

## QC

Use the repo root gate:

```bash
mix ci
```
