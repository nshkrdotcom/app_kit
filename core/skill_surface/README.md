# AppKit Skill Surface

DTO-only AppKit surface for governed skill admission, invocation, projection,
and trace refs.

The surface validates skill manifests through `jido_hive_skill_contracts` and
projects only refs, versions, posture, and release evidence. Raw prompt,
memory, provider, secret, credential, authorization, and private-state bodies
are rejected before a DTO can be built.
