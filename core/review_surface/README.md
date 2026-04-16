# AppKit Review Surface

`AppKit.ReviewSurface` is the typed app-facing review queue and decision
surface.

Its default backend is `AppKit.Bridges.MezzanineBridge`, which keeps review
listings and review actions behind the stable `AppKit.Core.*` DTO contract.
