# AppKit Mezzanine Bridge

`AppKit.Bridges.MezzanineBridge` is the internal adapter layer that binds the
stable `AppKit.Core.*` contract to the lower `mezzanine_app_kit_bridge`
service seam.

It is an implementation unit inside `app_kit`, not a product-facing dependency
surface.
