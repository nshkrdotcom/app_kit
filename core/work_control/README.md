# Work Control

Reusable governed-run and work-submission helpers.

The public `AppKit.WorkControl` surface stays stable while the actual
implementation can be resolved through a backend module.

Standalone backends are passed with `AppKit.BackendStack` or the
`:work_backend` option. AppKit does not read runtime application environment to
select work-control behavior; callers pass the backend explicitly or use the
compiled default backend.
