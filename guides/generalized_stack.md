# AppKit Generalized Stack Boundary

## Responsibility

AppKit owns the northbound application boundary. Product repos express product
intent through AppKit surfaces and receive product-safe DTOs, controls,
projections, leases, and receipts.

AppKit does not own durable workflow truth, authority policy, connector
execution, lane execution, or primitive persistence. Those remain in
Mezzanine, Citadel, Jido Integration, Execution Plane, and GroundPlane.

## Public Interfaces

Primary public package groups:

- `core/work_surface`, `core/work_control`, `core/headless_surface`,
  `core/runtime_gateway`, and `core/run_governance`
- `core/operator_surface`, `core/review_surface`, `core/installation_surface`,
  and `core/scope_objects`
- semantic and support surfaces for chat, domain, prompt, guardrail, memory,
  budget, cost, eval, replay, coordination, optimization, adaptive control,
  skill, and hive use cases
- `web/*` packages for reusable operator-facing UI surfaces
- `bridges/*` packages for explicit lower-boundary translation

DTOs exposed northbound must be stable, product-safe, tenant-scoped, and free
of lower private structs.

## Dependency Rules

Allowed dependencies:

- lower published contracts and documented bridge APIs;
- StackLab scanner fixtures and proof receipts used by tests;
- GroundPlane primitives only when the concept is a reusable primitive.

Forbidden dependencies:

- product imports of lower repo internals through AppKit convenience paths;
- generic AppKit surfaces that pick a concrete provider by default;
- direct connector, lane, workflow, or store calls from product-facing modules.

## Provider Vocabulary Zoning

Provider names may appear as product data, user-facing product terminology,
receipt facts, trace facts, adapter metadata, and migration fixtures. Generic
AppKit commands should use product roles, source kinds, operation classes,
binding refs, credential lease refs, and receipt refs.

When provider-specific behavior is needed, keep it in product config, explicit
adapter data, or a bridge module that translates a generic AppKit surface into a
lower binding-driven request.

## Extravaganza Cutover Proof

The current Extravaganza product path is the reference proof for this boundary.
The product still exposes provider-named examples where those names are part of
the product, but governed calls enter AppKit through generic work, source,
runtime, and headless surfaces.

The live proof completed these lanes through AppKit and the lower stack:

- issue-tracker source discovery and current-state readback;
- source publication create, update fallback, and same-state update;
- dynamic source-tool execution;
- coding-agent runtime turn execution;
- proposed-change evidence collection;
- proposed-change cleanup, including a disposable destructive fixture.

Route evidence returned to the product includes role, binding, manifest,
authority, connector-binding, credential-lease, lower-request, receipt,
projection, evidence, and trace refs. Those refs are the northbound proof that
provider facts are data selected below AppKit, not AppKit-level control flow.

The old provider-shaped AppKit public methods are treated as removed APIs.
`test/app_kit/generic_surface_static_test.exs` protects that posture by scanning
the public surface for the removed names. If a future product needs a new lower
capability, add a role-ref based AppKit surface and map it through a bridge;
do not reintroduce provider-named public calls.

## Cleanup Ownership

AppKit cleanup work means deleting product bypasses, provider-default dispatch,
stale DTO aliases, and bridge-root shortcuts after the replacement surface is
tested. Do not keep comments that describe removed paths as active guidance.
