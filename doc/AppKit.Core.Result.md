# `AppKit.Core.Result`

Stable app-facing result wrapper for northbound surfaces.

# `state`

```elixir
@type state() :: :accepted | :scheduled | :waiting_review | :projected | :rejected
```

# `surface`

```elixir
@type surface() ::
  :chat | :domain | :operator | :work_control | :runtime_gateway | :conversation
```

# `t`

```elixir
@type t() :: %AppKit.Core.Result{
  meta: map(),
  payload: map(),
  state: state(),
  surface: surface()
}
```

# `new`

```elixir
@spec new(map() | keyword()) :: {:ok, t()} | {:error, atom()}
```

# `states`

```elixir
@spec states() :: [state()]
```

# `surfaces`

```elixir
@spec surfaces() :: [surface()]
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
