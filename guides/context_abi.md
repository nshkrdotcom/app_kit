# AppKit Context ABI Surface

AppKit owns product-safe context, model, evaluation, cost, replay,
optimization, coordination, and operator projections. It is the only supported
product boundary for governed NSHKR writes and reads.

## Public Surface

`core/context_surface` exposes product-safe context packet and AI run summaries.
It depends on Mezzanine projections and redacted refs, not direct calls into
OuterBrain, Citadel, Jido Integration, or AITrace internals.

## Boundary Rules

Product code must not import lower owner packages to compile context, render
prompts, execute models, or inspect raw trace payloads. AppKit returns bounded
summary DTOs with context packet refs, authority refs, model invocation refs,
eval refs, cost summaries, replay refs, and safe projection state.

`core/context_surface` accepts only canonical lowercase `sha256:<64 hex>`
packet hashes. `core/eval_surface` rejects raw prompt, provider payload,
memory body, private tool output, credential, and `raw_*` fields recursively.
This keeps the product ABI ref-only even when lower proofs include richer
evidence.

## Local QC

```bash
mix ci
```

StackLab proves that product paths enter through AppKit and do not bypass the
lower owner boundaries.
