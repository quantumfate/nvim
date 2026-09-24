<!-- Keymap reference. Options, filetypes and autocmds are one file each and
     documented in their own headers. -->

# Keymaps

## Layout

Adapted for my [Programmer Dvorak Layout](https://github.com/quantumfate/system-config/blob/main/roles/keyboard).

```text
-  =  ]   forward / next          _  =  [   backward / previous
```

**Counts are expensive.** Digits are the shifted level of the number row, so
`7j` is a chord. Reach for structure instead, in this order:

1. a structural motion — `-f`, `_c`, `g_f`
2. flash — `s` plus two characters
3. a textobject with `n` / `l` — `cin(` needs no count at all
4. a count, only for 2 or 3

## Pick the scale

| Distance                    | Tool                 | Keys                      |
| --------------------------- | -------------------- | ------------------------- |
| Within the line             | `f` / `t` + `;`      | `dt(`                     |
| Visible on screen           | flash                | `s` + 2 chars + label     |
| Within the function         | search, `%`, `{` `}` | `/name` `*`               |
| Within the file, structural | bracket motions      | `-f` `_c` then `;`        |
| Within the file, by name    | pickers              | `<leader>fs` `<leader>cn` |
| Another file                | LSP, harpoon, marks  | `gd` `<C-h>` `` `A ``     |

## Textobjects — mini.ai

```text
operator  +  count  +  a | i | an | in | al | il  +  object
```

`a` around, `i` inside, `n` next, `l` last. `g_` / `g-` jump to an object's start
/ end without an operator.

| Key     | Object                     | Key     | Object                      |
| ------- | -------------------------- | ------- | --------------------------- |
| `f`     | function                   | `a`     | argument                    |
| `c`     | class                      | `t`     | tag                         |
| `o`     | block / conditional / loop | `i`     | indent block                |
| `u` `U` | function call              | `d`     | digits                      |
| `v`     | assignment (`iv` = value)  | `e`     | CamelCase / snake_case part |
| `r`     | return statement           | `g`     | entire buffer               |
| `C`     | comment                    | `q` `b` | any quote / any bracket     |

```text
dif     delete the function body        cin(   change inside the NEXT parens
vaf     select the whole function       dala   delete the LAST argument
civ     replace an assignment's value   g_f    start of enclosing function
dar     delete a return statement       d g-f  delete to end of function
```

`cin(` and `dala` are the payoff: they operate on things the cursor is not in.

## Structural motions — treesitter

Lowercase lands on the node start, uppercase on the node end.

| Key       | Node      | Key       | Node        |
| --------- | --------- | --------- | ----------- |
| `-f` `_f` | function  | `-i` `_i` | conditional |
| `-c` `_c` | class     | `-l` `_l` | loop        |
| `-a` `_a` | parameter | `-v` `_v` | assignment  |
| `-o` `_o` | block     | `-r` `_r` | return      |

**`;` repeats the last motion, `,` reverses it.** `-f;;;` walks the file by
function — press the prefix once, then walk. `;` still repeats `f` / `t` when
that was the last move.

`-f` leaves the current function; `g_f` stays inside it and goes to its start;
`vaf` does not move at all and selects it.

## Selection

```text
<C-space>   grow the selection to the enclosing node
<BS>        shrink back one step
S           flash treesitter — label every node, jump to one
```

## Moving code

Four directions on the right hand's home row, which occupies the physical slots
QWERTY gives `hjkl`:

```text
<A-d>  parameter left     <A-n>  parameter right
<A-h>  line / selection down     <A-t>  line / selection up
```

```text
<leader>ma / mA   swap parameter forward / backward
<leader>mf / mF   swap function
<leader>mc / mC   swap class
<leader>mv / mV   swap assignment
<leader>md / mD   duplicate the enclosing function / class
```

Relocating rather than reordering: `daf` → `-f` → `p`. Surround lives on `gs`
so `s` stays free for flash: `gsaif)` wraps a function body in parens.

## Jumping

```text
s   jump anywhere on screen: 2 chars, then a label
S   label treesitter nodes
r   remote — operate on a distant object without leaving home (operator-pending)
R   treesitter search

/ ? * #     search; `/` is an operator motion: d/return<CR>
% { } H M L zz zt zb

ma `a       buffer-local mark            mA `A   global mark, survives files
`` `.       last position / last edit    g; g,   walk the changelist
<C-o> <C-i> jumplist back / forward
```

`gn` selects the next search match as a textobject — `/oldName<CR> cgn newName<Esc> . . .`

### Multiple cursors from motions

`gz` arms a capture; the next motion leaves a cursor behind and lands the main
one (`plugins/editor/multicursor.lua` + `lua/features/multicursor.lua`):

```text
gz w gze gz} gz-q   cursor from the next word / word end / paragraph
gzf( gzt.           f/t read their pending char from the capture

while cursors exist the bare keys join in — each motion spawns again:
w b e $ ^ { } f t   spawn at the next destination, keep collecting
Q{motion}           move ONLY the main cursor (reposition without spawning)
]m [m               rotate which cursor is the main one
<Esc>               collapse back to a single cursor
```

Nothing outside a session is remapped: the layer arms through the plugin's
own keymap layer, so which-key renders the runtime-enabled set by construction.
`flash` keeps `s`, gitsigns keeps `]c`/`[c`, harpoon keeps `<C-n>`, and `n`/`N`
still walk all cursors to the next match mid-session.

## Symbols, LSP, files

```text
gd gD gy gI gO        definition, declaration, type, implementation, symbols
grr grn gra gri grt   references, rename, code action, implementation, type
K                     hover
<leader>cn            navbuddy symbol tree
<leader>ff            find all files in project (root)
<leader>fcf           find code files in project (no docs/CI)
<leader>fc/           grep code in project (no docs/CI)
<leader>ftf           find test files (tests/test/spec dirs)
<leader>ft/           grep tests (tests/test/spec dirs)
<leader>flf           find files in current file's dir
<leader>fl/           grep in current file's dir
<leader>fs            smart find files (cwd)
<leader>/             grep everything (cwd)
<leader>st / sT       search todo comments (all / TODO+FIX+FIXME)

<leader>ha            harpoon add
<C-h> <C-t> <C-n>     harpoon slots 1-3
<leader>hl            harpoon picker
<C-f>                 tmux sessionizer
```

## Leader groups

The same question gets the same key in every language. Which-key shows only the
ones the current buffer can actually answer, so an empty slot means the adapter or
the language server does not implement it — not that the key is free.

| Group       | Question                            | Owned by                          |
| ----------- | ----------------------------------- | --------------------------------- |
| `<leader>b` | build / run this                    | `lua/features/lang/` adapters     |
| `<leader>t` | test this                           | neotest + the lang adapter's `ta` |
| `<leader>d` | debug this                          | nvim-dap, `lua/features/crash/`   |
| `<leader>v` | what does the compiler see and emit | lang adapters + LSP hierarchies   |
| `<leader>x` | what does the binary say            | `lua/features/sys/`               |
| `<leader>r` | restructure this                    | `lua/features/refactor/`          |
| `<leader>e` | explorer sidebar                    | `lua/features/ui/sidebar.lua`     |
| `<leader>u` | toggle an editor option             | snacks.toggle                     |
| `<leader>B` | buffer management                   | bufferline / snacks               |

### Build, test, debug

One loop, three prefixes, no language in the keys:

```text
<leader>bb  build                 <leader>tt  nearest test
<leader>br  run                   <leader>tf  tests in this file
<leader>bR  run, choose target    <leader>ts  test summary
<leader>bc  check, no codegen     <leader>to  test output
<leader>bo  open the build file   <leader>ta  test via the language's own runner
<leader>bi  reload project index  <leader>td  debug the nearest test

<leader>dbt  breakpoint           <leader>dSc  continue      <leader>dw  watch expression
<leader>di   step into            <leader>dSt  terminate     <leader>dk  hover value
<leader>do   step over            <leader>dc   crash dumps
<leader>dO   step out             <leader>dD   modal debug mode
```

Modal debug mode (`<leader>dD`, and automatic on a DAP launch) drops the leader
entirely for the duration: `c` continue, `n` step over, `s` step into, `o` step out,
`b` breakpoint, `q` exit. Exiting restores every binding it shadowed.

`:LangInfo` prints the build/test/view table for the current buffer with a yes/— per
capability, which is the fastest answer to "is this wired here".

### Explorer

One window on the left edge, three views taking turns in it. Each key toggles — the
key that opened a view closes it, a different key swaps the view in place.

```text
<leader>ee  Files      <leader>eb  Buffers      <leader>eg  Git status (also <leader>ge)
<leader>eE  Files, rooted at the current file   <leader>wh  jump into the sidebar
```

## Where the bindings live

| Layer                  | Owns                                | File                                |
| ---------------------- | ----------------------------------- | ----------------------------------- |
| flash                  | `s` `S` `r` `R`                     | `lua/plugins/editor/flash.lua`      |
| treesitter-textobjects | motions, `<leader>m` swaps, `;` `,` | `lua/plugins/editor/treesitter.lua` |
| mini.ai                | `a` `i` `n` `l` `g-` `g_`           | `lua/plugins/lib/mini-ai.lua`       |
| mini.surround          | `gs*`                               | `lua/plugins/lib/mini-surround.lua` |
| LSP                    | `g*` navigation                     | `lua/features/lsp/keymaps.lua`      |
| lang adapters          | `<leader>b` `<leader>t` `<leader>v` | `lua/features/lang/`                |
| ui                     | `<leader>e` sidebar, `<leader>dD`   | `lua/features/ui/`                  |
| config                 | prefixes, windows, lists, drags     | `lua/core/keymaps.lua`              |

If a mapping does not behave as documented, `:verbose map <lhs>` names the file
that won — anything loading on an event overrides `lua/core/keymaps.lua`.
