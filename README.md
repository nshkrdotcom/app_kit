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

AppKit is the shared app-facing surface monorepo for the nshkr platform core.

The repository is intentionally generic for now. It exists to provide the stable app-consumption layer above the lower stack so product applications do not need to stitch `outer_brain`, Citadel, `jido_integration`, and execution-facing details together manually.

## Scope

- host-facing surfaces
- stack composition and wiring
- default bridges across core layers
- app-level configuration contracts
- reusable entrypoints for product applications

## Starter Surface Areas

- chat-facing surfaces
- typed domain-facing surfaces
- operator-facing surfaces

## Status

Starter repository. The exact surface inventory will tighten as the first real consuming applications land.

## Development

The project targets Elixir `~> 1.19` and Erlang/OTP `28`. The pinned toolchain lives in [`.tool-versions`](./.tool-versions).

```bash
mix deps.get
mix test
```

## Documentation

- [docs/overview.md](./docs/overview.md)
- [docs/surfaces.md](./docs/surfaces.md)
- [docs/composition.md](./docs/composition.md)
- [CHANGELOG.md](./CHANGELOG.md)

## License

MIT. Copyright (c) 2026 nshkrdotcom. See [LICENSE](./LICENSE).
