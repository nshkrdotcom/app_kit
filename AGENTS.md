# Monorepo Project Map

- `./bridges/domain_bridge/mix.exs`: App-facing bridge over the citadel_domain_surface seam
- `./bridges/integration_bridge/mix.exs`: App-facing bridge over lower durable run and review seams
- `./bridges/mezzanine_bridge/mix.exs`: Internal AppKit bridge over lower-backed Mezzanine service modules
- `./bridges/outer_brain_bridge/mix.exs`: App-facing bridge over the outer_brain seam
- `./bridges/projection_bridge/mix.exs`: App-facing bridge for projection and operator read seams
- `./core/app_config/mix.exs`: Normalized app-facing config contracts for the AppKit workspace
- `./core/app_kit_core/mix.exs`: Shared surface-core contracts for the AppKit workspace
- `./core/chat_surface/mix.exs`: Host-facing chat entrypoints for the AppKit workspace
- `./core/conversation_bridge/mix.exs`: Reusable follow-up and live-update helpers for the AppKit workspace
- `./core/domain_surface/mix.exs`: Typed app-facing composition above citadel_domain_surface
- `./core/installation_surface/mix.exs`: Typed installation lifecycle surface for the AppKit workspace
- `./core/model_surface/mix.exs`: Product-safe model and endpoint inventory projection surface
- `./core/operator_surface/mix.exs`: Operator-facing composition around review and projection reads
- `./core/optimization_surface/mix.exs`: Product-safe GEPA optimization command and projection surface
- `./core/review_surface/mix.exs`: Typed review-queue and decision surface for the AppKit workspace
- `./core/run_governance/mix.exs`: Reusable run-governance helpers for the AppKit workspace
- `./core/runtime_gateway/mix.exs`: App-facing runtime gateway descriptors for the AppKit workspace
- `./core/scope_objects/mix.exs`: Reusable scope and target helpers for the AppKit workspace
- `./core/work_control/mix.exs`: Reusable work-control helpers for the AppKit workspace
- `./core/work_surface/mix.exs`: Typed governed-object queue and detail surface for the AppKit workspace
- `./examples/reference_host/mix.exs`: Reference host proving the AppKit northbound composition path
- `./mix.exs`: Workspace root for the AppKit northbound application-surface monorepo

# AGENTS.md

## Onboarding

Read `ONBOARDING.md` first for the repo's one-screen ownership, first command,
and proof path.

## Temporal developer environment

Temporal CLI is implicitly available on this workstation as `temporal` for local durable-workflow development. Do not make repo code silently depend on that implicit machine state; prefer explicit scripts, documented versions, and README-tracked ergonomics work.

## Native Temporal development substrate

When Temporal runtime behavior is required, use the stack substrate in `/home/home/p/g/n/mezzanine`:

```bash
just dev-up
just dev-status
just dev-logs
just temporal-ui
```

Do not invent raw `temporal server start-dev` commands for normal work. Do not reset local Temporal state unless the user explicitly approves `just temporal-reset-confirm`.

## Dependency Sources

- Dependency source selection is handled by `build_support/dependency_sources.exs` and `build_support/dependency_sources.config.exs`.
- Local dependency overrides use `.dependency_sources.local.exs`.
- Dependency source selection must not use environment variables.
- Same-repo workspace package paths may stay in their local `mix.exs` files; cross-repo dependencies that need fallback behavior belong in the dependency-source manifest.
- Weld checks helper drift, dependency-source manifests, clone/publish checks, and publish order for this repo; keep the committed dependency on the released Hex Weld line.

## Runtime Env

- Runtime application code under `lib/**`, package `lib/**`, example `lib/**`, and Mix task modules must not call direct OS env APIs such as `System.get_env`, `System.fetch_env`, `System.put_env`, or `System.delete_env`.
- Runtime/deployment env reads belong in `config/runtime.exs` or a `Config.Provider`.
- Mix tasks, examples, and harnesses should accept explicit flags, app config, or caller-supplied env maps instead of reading or mutating process env.

## Live Provider Checks

For live provider checks, use `~/scripts/with_bash_secrets <command>`. It sources
`~/.bash/bash_secrets` and execs the command. Do not print secret values. Pipe
`LINEAR_API_KEY` via stdin for Linear examples. GitHub live examples use `gh auth`
or `GH_TOKEN`/`GITHUB_TOKEN` from the wrapper. Codex SDK examples use the existing
Codex/OpenAI machine auth through the wrapper. Live provider smoke is not product
acceptance unless it runs the product-owned Extravaganza command path.

<!-- gn-ten:repo-agent:start repo=app_kit source_sha=ab276c0640772b73065ab12bf05d77be51f1bb67 -->
# app_kit Agent Instructions Draft

## Owns

- Product-safe northbound surfaces.
- Public DTOs for product reads, writes, reviews, operator controls, runtime
  readback, semantic assist, trace lookup, and leased lower reads.
- Boundary scanners that keep products on AppKit.

## Does Not Own

- Product UI.
- Mezzanine runtime internals.
- Citadel policy engine.
- Jido Integration connector internals.
- Execution Plane lanes.

## Allowed Dependencies

- Public contract artifacts from Mezzanine, OuterBrain, Citadel, Jido
  Integration, Execution Plane, GroundPlane, and AITrace when routed through
  bridge packages.

## Forbidden Imports

- Product runtime code must not be added here.
- AppKit surfaces must not call lower internals in ways that bypass bridge
  behaviours or DTO constructors.

## Verification

- `mix ci`
- AppKit no-bypass scanner against product and hazmat profiles.

## Escalation

If a lower primitive is missing, add it in the lower owner repo first, then
return to AppKit.
<!-- gn-ten:repo-agent:end -->

## Blitz 0.3.0 operational note

Root workspace Blitz uses published Hex `~> 0.3.0` by default; `.blitz/` is committed compact impact state after green QC. Source and `mix.exs` changes cascade through reverse workspace dependencies; docs-only changes should stay owner-local.
