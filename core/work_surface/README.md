# AppKit Work Surface

`AppKit.WorkSurface` is the app-facing typed surface for governed-object intake,
queue reads, detail reads, and named projections.

In Phase `3.2` it defaults to `AppKit.Bridges.MezzanineBridge`, which keeps the
public contract in `app_kit_core` while routing the lower implementation through
the internal app-kit mezzanine bridge service layer.
