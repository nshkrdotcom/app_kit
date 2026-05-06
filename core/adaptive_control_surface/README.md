# AppKit Adaptive Control Surface

`app_kit_adaptive_control_surface` exposes DTO-only operator projections for
closed-loop adaptive control: shadow comparison, canary state, threshold
status, budget impact, approval, promotion readiness, rollback availability,
artifact locks, stale artifact rejection, and audit refs.

It projects refs only and never exposes raw prompts, provider payloads, model
outputs, memory bodies, credentials, or operator-private payloads.
