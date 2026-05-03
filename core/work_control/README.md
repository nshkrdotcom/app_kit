# Work Control

Reusable governed-run and work-submission helpers.

The public `AppKit.WorkControl` surface stays stable while the actual
implementation can be resolved through a backend module.

Standalone backends can be read from `config :app_kit_core, :work_backend,
...`. Governed calls ignore that fallback when `:governed?` or authority-ref
options are present; callers must pass `:work_backend` directly or use the
compiled default backend.
