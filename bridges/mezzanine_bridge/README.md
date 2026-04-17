# AppKit Mezzanine Bridge

`AppKit.Bridges.MezzanineBridge` is the internal adapter layer that binds the
stable `AppKit.Core.*` contract to lower-backed Mezzanine service modules that
live inside this package.

It is an implementation unit inside `app_kit`, not a product-facing dependency
surface.
