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
- `./core/operator_surface/mix.exs`: Operator-facing composition around review and projection reads
- `./core/review_surface/mix.exs`: Typed review-queue and decision surface for the AppKit workspace
- `./core/run_governance/mix.exs`: Reusable run-governance helpers for the AppKit workspace
- `./core/runtime_gateway/mix.exs`: App-facing runtime gateway descriptors for the AppKit workspace
- `./core/scope_objects/mix.exs`: Reusable scope and target helpers for the AppKit workspace
- `./core/work_control/mix.exs`: Reusable work-control helpers for the AppKit workspace
- `./core/work_surface/mix.exs`: Typed governed-object queue and detail surface for the AppKit workspace
- `./examples/reference_host/mix.exs`: Reference host proving the AppKit northbound composition path
- `./mix.exs`: Workspace root for the AppKit northbound application-surface monorepo

# AGENTS.md

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
