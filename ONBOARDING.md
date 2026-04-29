# app_kit Onboarding

Read `AGENTS.md` first; the managed gn-ten section is the repo contract.
`CLAUDE.md` must stay a one-line compatibility shim containing `@AGENTS.md`.

## Owns

Product-safe northbound surfaces, public DTOs, AppKit bridges, product boundary
scanners, and the reusable app-facing API seam.

## Does Not Own

Product UI, Mezzanine internals, Citadel policy internals, JidoIntegration
connector internals, ExecutionPlane lanes, or provider SDK behavior.

## First Task

```bash
cd /home/home/p/g/n/app_kit
mix ci
cd /home/home/p/g/n/stack_lab
mix gn_ten.plan --repo app_kit
```

## Proofs

StackLab owns assembled proof. Use `/home/home/p/g/n/stack_lab/proof_matrix.yml`
and `/home/home/p/g/n/stack_lab/docs/gn_ten_proof_matrix.md`.

## Common Changes

Products and hosts call AppKit. Add or adjust public DTO constructors instead
of letting product code import lower internals.
