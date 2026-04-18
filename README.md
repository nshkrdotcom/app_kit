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
