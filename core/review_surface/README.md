# AppKit Review Surface

`AppKit.ReviewSurface` is the typed app-facing review queue and decision
surface.

Its default backend is `AppKit.Bridges.MezzanineBridge`, which keeps review
listings and review actions behind the stable `AppKit.Core.*` DTO contract.

Standalone backends can be read from `config :app_kit_core, :review_backend,
...`. Governed calls ignore that fallback when `:governed?` or authority-ref
options are present; callers must pass `:review_backend` directly or use the
compiled default bridge.
