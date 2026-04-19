<p align="center">
  <img src="assets/app_kit.svg" width="200" height="200" alt="AppKit logo" />
</p>

<p align="center">
  <a href="https://github.com/nshkrdotcom/app_kit/actions/workflows/ci.yml">
    <img alt="GitHub Actions Workflow Status" src="https://github.com/nshkrdotcom/app_kit/actions/workflows/ci.yml/badge.svg" />
  </a>
  <a href="https://github.com/nshkrdotcom/app_kit/blob/main/LICENSE">
    <img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-0b0f14.svg" />
  </a>
</p>

# AppKit

AppKit is the northbound application-surface workspace for the nshkr platform
core.

It exists so product applications can consume stable chat, domain, operator,
work-control, runtime-gateway, and conversation surfaces without stitching the
lower stack manually.

AppKit is also the product boundary enforcement point. Product repos must use
AppKit surfaces for governed writes, operator reads, reviews, installation
bootstrap, semantic assist, trace lookup, and leased lower read access. Direct
product calls into Mezzanine, Citadel, Jido Integration, or Execution Plane are
boundary violations unless the product is authoring a pure `Mezzanine.Pack`
model contract.

## Scope

- chat-facing surfaces
- typed domain-facing surfaces
- operator-facing surfaces
- reusable work-control and governed-run surfaces
- runtime gateways and conversation bridges
- host-scope and managed-target helpers
- default cross-stack composition

## Status

Active workspace buildout. The repo uses a non-umbrella workspace layout with
core surface packages, bridge packages, and a proving example host.

## Development

The project targets Elixir `~> 1.19` and Erlang/OTP `28`. The pinned toolchain
lives in `.tool-versions`.

```bash
mix deps.get
mix ci
```

Runtime proof output must stay out of tracked paths. Bridge packages that need
mutable archival or trace artifacts write to OS temp roots or ignored generated
directories, and `mix ci` should leave the worktree clean.

The AppKit-owned product-boundary scanner is part of the root CI gate:

```bash
mix app_kit.no_bypass --profile hazmat \
  --include "core/**/*.ex" \
  --include "bridges/**/*.ex" \
  --include "examples/**/*.ex"
```

Product repos run the same task from this workspace with `--root` and both
profiles. `product` blocks direct governed-write imports into Mezzanine,
Citadel, Jido Integration, and Execution Plane while allowing the pure
`Mezzanine.Pack` authoring contract. `hazmat` separately blocks direct
Execution Plane usage so attach and stream behavior stays behind AppKit and
Mezzanine leases.

Default AppKit surface backends are configured under the real OTP application
`:app_kit_core`, for example `:installation_backend`, `:work_query_backend`,
`:review_backend`, `:operator_backend`, and `:work_backend`. Products may pass
explicit backend options for tests, but product runtime configuration should
not create a synthetic `:app_kit` config namespace.

Lower-backed operator reads must stay behind AppKit surfaces. The Mezzanine
bridge carries read and stream-attach `authorization_scope` in public DTOs so
product callers cannot bypass tenant-scoped lease checks or call lower-facts
stores with only a raw token.

The welded `app_kit_core` artifact is tracked through the prepared bundle flow:

```bash
mix release.prepare
mix release.track
mix release.archive
```

`mix release.track` updates the orphan-backed `projection/app_kit_core` branch
so downstream repos can pin a real generated-source ref before any formal
release boundary exists.

## Documentation

- `docs/overview.md`
- `docs/layout.md`
- `docs/surfaces.md`
- `docs/composition.md`
- `CHANGELOG.md`

This project is licensed under the MIT License.
(c) 2026 nshkrdotcom. See `LICENSE`.

## Temporal developer environment

Temporal CLI is expected to be available as `temporal` on this developer workstation for local durable-workflow development. Current provisioning is machine-level dotfiles setup, not a repo-local dependency.

TODO: make Temporal ergonomics explicit for developers by adding repo-local setup scripts, version expectations, and fallback instructions so the tool is not silently assumed from the workstation.

## Native Temporal development substrate

Temporal runtime development is managed from `/home/home/p/g/n/mezzanine` through the repo-owned `just` workflow, not by manually starting ad hoc Temporal processes.

Use:

```bash
cd /home/home/p/g/n/mezzanine
just dev-up
just dev-status
just dev-logs
just temporal-ui
```

Expected local contract: `127.0.0.1:7233`, UI `http://127.0.0.1:8233`, namespace `default`, native service `mezzanine-temporal-dev.service`, persistent state `~/.local/share/temporal/dev-server.db`.

See `docs/temporal_operator_surface.md` for the AppKit boundary around Temporal-backed operator state. AppKit consumes Mezzanine workflow projections/facades and must not import Temporal directly.
