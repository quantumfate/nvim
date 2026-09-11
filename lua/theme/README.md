# Theme

`:Theme <name>` switches and remembers. `:Theme` reports the active one.

## Roles

Highlights are written against a ramp, not a palette. Every scheme has one.

| Role                            | Used for                                   |
| ------------------------------- | ------------------------------------------ |
| `ramp[1]`                       | editor background                          |
| `ramp[2..4]`                    | structure: indent guide, border, separator |
| `ramp[5..7]`                    | metadata text                              |
| `ramp[8]`                       | content                                    |
| `accent`                        | the one active thing on screen             |
| `ok warn err info hint changed` | status                                     |

## Flow

```text
:Theme gruvbox
   └─ colorscheme gruvbox
         └─ ColorScheme autocmd   ← fires for ANY scheme, from any source
               ├─ roles.get()      derive from live highlights, then adapter
               └─ highlights.apply()
```

The autocmd is why the scheme and the hand-written groups cannot drift apart.

## Files

| File             | Holds                                          |
| ---------------- | ---------------------------------------------- |
| `roles.lua`      | the contract, and the derive-from-scheme guess |
| `highlights.lua` | ~130 groups, by role                           |
| `adapters/*.lua` | optional per-scheme corrections                |
| `color.lua`      | blend, luminance, read a group                 |

## Adapters are optional

`roles.derive()` reads the ramp back out of `Normal`, `CursorLine`, `Visual`,
`Comment` and `Diagnostic*`, interpolates missing steps, and rejects borrowed values
that break the gradient. An unknown scheme themes correctly with no adapter.

An adapter only corrects that guess:

```lua
-- lua/theme/adapters/gruvbox.lua
return {
  roles = function(_)
    local p = require("gruvbox").palette
    return { ramp = { p.dark0, p.dark1, p.dark2, p.dark3,
                      p.gray, p.light4, p.light2, p.light1 },
             accent = p.bright_purple }
  end,
}
```

Partial is fine — anything omitted stays derived.
