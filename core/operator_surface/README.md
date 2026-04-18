# Operator Surface

Operator-facing composition around review and projection reads.

The public `AppKit.OperatorSurface` surface stays stable while projection and
review behavior can be resolved through a backend module.

Default backend leases include authorization scope for downstream lower-backed
operator reads. Bridge backends must preserve that scope in `ReadLease` and
`StreamAttachLease` DTOs so Mezzanine can fail closed on tenant, installation,
subject, execution, or trace mismatch before any lower-facts read is attempted.
