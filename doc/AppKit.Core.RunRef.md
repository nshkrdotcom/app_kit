# `AppKit.Core.RunRef`

Stable run reference used across AppKit surfaces.

# `t`

```elixir
@type t() :: %AppKit.Core.RunRef{
  metadata: map(),
  run_id: String.t(),
  scope_id: String.t()
}
```

# `new`

```elixir
@spec new(map() | keyword()) :: {:ok, t()} | {:error, atom()}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
