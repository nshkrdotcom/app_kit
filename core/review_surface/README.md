# AppKit Review Surface

`AppKit.ReviewSurface` is the typed app-facing review queue and decision
surface.

Its default backend is `AppKit.Bridges.MezzanineBridge`, which keeps review
listings and review actions behind the stable `AppKit.Core.*` DTO contract.

The default backend is read from `config :app_kit_core, :review_backend, ...`
unless callers pass `:review_backend` directly in options.
