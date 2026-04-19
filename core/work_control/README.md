# Work Control

Reusable governed-run and work-submission helpers.

The public `AppKit.WorkControl` surface stays stable while the actual
implementation can be resolved through a backend module.

The default backend is read from `config :app_kit_core, :work_backend, ...`
unless callers pass `:work_backend` directly in options.
