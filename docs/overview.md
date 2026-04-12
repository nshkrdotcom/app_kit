# Overview

AppKit is the northbound application-surface workspace that sits above
`outer_brain`, `jido_domain`, Citadel, and `jido_integration`.

It owns the reusable app-facing seams that products should consume directly:

- chat surfaces
- domain surfaces
- operator surfaces
- work-control and run-governance surfaces
- runtime gateways
- conversation bridges
- scope and target helpers
- normalized app config

The repo is intentionally northbound. It does not own semantic authority,
policy authority, lower durable truth, or execution-plane realization.
