# AppKit Review Surface

`AppKit.ReviewSurface` is the typed app-facing review queue and decision
surface.

Its default backend is `AppKit.Bridges.MezzanineBridge`, which keeps review
listings and review actions behind the stable `AppKit.Core.*` DTO contract.

Standalone backends are passed with `AppKit.BackendStack` or the
`:review_backend` option. AppKit does not read runtime application environment
to select review behavior; callers pass the backend explicitly or use the
compiled default bridge.
