# Outer Brain Bridge

App-facing bridge to the semantic runtime seam.

The bridge accepts product-safe host scope, turn text, routing context, and
trace identity, then delegates semantic work to the configured Outer Brain
runtime. It does not make AppKit a memory engine and it does not let products
write provider memory or platform truth directly.

For phase-3 product proofs this is the semantic-assist path: product code calls
AppKit, AppKit preserves request-edge trace identity and tenant scope, and the
semantic runtime remains owned by Outer Brain.

Semantic runtime failures cross this bridge only as
`OuterBrain.Contracts.SemanticFailure` carriers. The bridge fills missing
tenant, semantic-session, causal-unit, request-trace, provenance, and operator
message defaults from `HostScope` and the request edge, while preserving any
provenance supplied by the semantic runtime. AppKit does not interpret provider
memory, RAG, or model-specific details.
