# AppKit Installation Surface

`AppKit.InstallationSurface` is the typed app-facing installation lifecycle
surface.

Its default backend is `AppKit.Bridges.MezzanineBridge`, which keeps tenant
installation operations behind the stable `AppKit.Core.*` DTO contract.

Standalone backends can be read from `config :app_kit_core,
:installation_backend, ...`. Governed calls ignore that fallback when
`:governed?` or authority-ref options are present; callers must pass
`:installation_backend` directly or use the compiled default bridge.

## Authoring Bundle Import

`import_authoring_bundle/3` is an operator import action, not a product
template shortcut. Callers pass `AppKit.Core.AuthoringBundleImport`; the
surface forwards it through the configured installation backend so the
Mezzanine bridge can enforce tenant context, checksum/signature validation,
policy refs, trusted descriptors, stale revision checks, and the no
pack-authored-platform-migration rule before lower runtime activation.
