# AppKit Installation Surface

`AppKit.InstallationSurface` is the typed app-facing installation lifecycle
surface.

Its default backend is `AppKit.Bridges.MezzanineBridge`, which keeps tenant
installation operations behind the stable `AppKit.Core.*` DTO contract.
