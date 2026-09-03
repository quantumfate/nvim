;; extends

; `{{ }}` / `{% %}` delimiters
([
  (string_scalar)
  (single_quote_scalar)
  (double_quote_scalar)
  (block_scalar)
] @injection.content
  (#lua-match? @injection.content "{[{%%]")
  (#set! injection.language "jinja"))
