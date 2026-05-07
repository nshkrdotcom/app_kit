# Projection Bridge

App-facing bridge for read-model projections and operator views.

Phase 7 projection bridge payloads include memory-default persistence posture
evidence and preserve AppKit as a read-only projection consumer. The bridge
does not persist raw prompt bodies, provider payload bodies, auth material, or
provider account secrets, and debug tap failure cannot mutate projection
payload state.
