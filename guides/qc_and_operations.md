# AppKit QC And Operations

## Local Commands

```bash
mix deps.get
mix ci
mix app_kit.schema_registry.verify
mix app_kit.no_bypass --profile hazmat --include "core/**/*.ex" --include "bridges/**/*.ex" --include "examples/**/*.ex"
```

Run package-local tests when changing a single surface, then run root `mix ci`
before commit.

## Scanner And Proof Obligations

AppKit-owned changes must keep these proof obligations green:

- schema registry verification for public DTOs;
- product no-bypass scanner coverage for product-facing paths;
- StackLab product fixture proof when a surface changes the product contract;
- no dynamic atom construction in runtime request parsing;
- no Regex usage in code or tests touched by the change;
- no unsupervised process starts.

## Secrets And Live Providers

AppKit must not read GitHub, Linear, or model-provider secrets directly.
Credential material reaches lower providers through product commands,
Mezzanine binding resolution, Citadel authority, and Jido Integration leases.

If an AppKit-driven acceptance path invokes GitHub or Linear through a product
command, run it by prefixing the command with:

```bash
~/scripts/with_bash_secrets
```

## Tenant, Observability, And Replay

Public DTOs that expose lower reads must carry tenant, authority, lease,
operation, and trace refs as data. AppKit may project AITrace or receipt refs
for product views, but it must not treat projections as policy authority.

## Documentation Checks

Keep `README.md` linked to this guide set. After doc edits, run:

```bash
test -f README.md
find guides -maxdepth 1 -type f -name '*.md' -print | sort
git diff --check -- README.md guides
```
