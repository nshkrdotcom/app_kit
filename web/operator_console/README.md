# AppKit Operator Console

DTO-only operator console shell and authorization render contracts. Product
web apps mount this package through product-local routes and pass AppKit DTOs
or bounded trace export refs; lower runtime stores and provider payloads are
not accepted.

Phase 15 extends the existing console section contract with
`adaptive_controls`. The section is still DTO-only: rows carry candidate
review, shadow state, canary state, promotion, rollback, and audit refs through
the same tenant check and redaction posture as memory, prompt, connector, and
other operator sections. Product code must supply AppKit surface DTOs, not
direct GEPA, TRINITY, provider SDK, lower runtime, DB, or trace objects.
