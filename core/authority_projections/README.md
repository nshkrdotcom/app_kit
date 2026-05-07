# AppKit Authority Projections

Phase 2 package for ref-only authority DTOs consumed by AppKit product
surfaces. It projects system authorization, provider account, connector
instance, credential handle, credential lease, native auth assertion, target
grant, operation policy, redaction, and evidence refs without carrying raw
credential material or provider payloads.

Phase 7 projection posture defaults to memory/ref-only storage and is
non-authoritative evidence. `:off` optional retention keeps projection
construction and provider effects available while marking projection retention
disabled. Debug tap failure is recorded as non-mutating posture evidence and
does not alter authority refs, target grants, or projection facts.

QC:

```sh
ASDF_ELIXIR_VERSION=1.19.5-otp-28 mix test
ASDF_ELIXIR_VERSION=1.19.5-otp-28 mix format --check-formatted
```
