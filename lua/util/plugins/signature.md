# signature

Add a parameter to the function under the cursor and to its call sites.

- `<leader>ra` / `:SigAdd bar:int=1` — cursor position in the parameter list picks the index; `!` prefix (`!*args`) inserts text verbatim.
- Call sites are edited when the parameter shifts existing ones, has no default, or the language lacks defaults. `<leader>rA` / `:SigAdd!` forces them.
- Call sites come from `textDocument/references`; anything unfixable lands in the quickfix list. Buffers are left unsaved.
- Languages live in `lua/plugins/lang/conf/signature.lua`; `find_decl`, `find_call`, `insert_pos` and `extra_edits` override or extend the generic steps.
- Lua also gains a `---@param` line when the signature already carries a doc block and the prompt names a type.
