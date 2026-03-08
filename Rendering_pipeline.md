# Rendering Pipeline

This document defines how a grammar-valid Talon Lite string is parsed and rendered into final output text.

## Inputs And Outputs

- Input: A string that matches [talon_lite_grammar.md](/Users/joyo/dictator/talon_lite_grammar.md).
- Output: Final rendered text.

## Core Responsibilities

- Parse expressions and operator calls.
- Maintain a brace stack for deferred closing tokens.
- Execute character/identifier operators.
- Handle bang behavior (`blark`) in top-level and operator contexts.

## Token Classes Used During Rendering

- Character tokens: letters, digits, punctuation, brace tokens.
- Identifier tokens: free-form identifier words.
- Operators:
  - Unary identifier: `word`
  - Unary character: `shift`
  - N-ary identifier: formatter operators (for example `hammer`)
  - N-ary character: currently none
- Special token: `blark`

## Brace Stack Model

Maintain a LIFO stack of pending closing braces.

Open-brace character behavior:
- `paren` inserts `(` and pushes `)`
- `square` inserts `[` and pushes `]`
- `angle` inserts `<` and pushes `>`
- `brace` inserts `{` and pushes `}`

## Bang Operator Semantics

### Top-Level `blark`

When `blark` is parsed as its own expression item:
- If brace stack is non-empty: pop and emit the top closing brace.
- If brace stack is empty: error.

### In N-ary Operator Calls

In grammar forms like `operator arg+ blark`, `blark` terminates argument collection for that operator call and is not rendered literally.

## Operator Semantics

### `word` (Unary Identifier)

Form: `word <identifier>`

Behavior:
- Insert identifier exactly as a word token output unit.
- Intended for explicit identifier insertion behavior under grammar control.

### `shift` (Unary Character)

Form: `shift <character>`

Behavior:
- For alphabetic character tokens: emit uppercase version.
- For punctuation and non-alphabetic symbols: no effect beyond normal character emission.

### N-ary Identifier Operators

Form: `<nary_identifier_operator> <identifier>+ blark`

Behavior:
- Collect identifiers until terminating `blark`.
- Apply formatter mapped to the specific operator.

Minimum expected mappings:
- `hammer yes no blark` -> `YesNo`
- `camel yes no blark` -> `yesNo`
- `snake yes no blark` -> `yes_no`
- `kebab yes no blark` -> `yes-no`
- `smash yes no blark` -> `yesno`

Additional operators follow the same collect-then-format pattern.

## Example: Stack-Based Bang Closing

Input sequence:
- `paren angle blark blark`

Execution:
1. `paren` -> output `(`, push `)`
2. `angle` -> output `<`, push `>`
3. `blark` -> pop `>`, output `>`
4. `blark` -> pop `)`, output `)`

Result:
- `(<>)`

## Rendering Algorithm (Reference)

```text
initialize output buffer
initialize empty brace stack

for each parsed expression item:
  if item is character:
    render character
    if character is opening brace token:
      push matching closer

  else if item is unary operator call:
    evaluate operator and emit output

  else if item is n-ary operator call:
    collect args until terminating blark
    format args by operator
    emit formatted text

  else if item is top-level blark:
    if stack non-empty: pop and emit closer
    else: fail

return output buffer as final text
```

## Invariants

- Input is grammar-valid before render starts.
- N-ary operators always terminate with `blark`.
- Brace stack order guarantees correct nested close emission.
- Rendering is deterministic for a given parsed input.
