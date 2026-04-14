# Workspace Layout

The repo is a non-umbrella workspace root.

Key groups:

- `core/app_kit_core`
- `core/chat_surface`
- `core/domain_surface`
- `core/operator_surface`
- `core/work_control`
- `core/run_governance`
- `core/runtime_gateway`
- `core/conversation_bridge`
- `core/scope_objects`
- `core/app_config`
- `bridges/*`
- `examples/reference_host`

This split keeps the app-facing surface coherent without collapsing the lower
stack into one opaque application.
