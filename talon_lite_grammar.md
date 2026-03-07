# Talon Lite Grammar

This document defines the current Talon Lite grammar and token sets.

## Design Notes

- The grammar is intended to be unambiguous because operator symbols are disjoint from character terminals.
- `blark` is the special standalone bang token.
- Character tokens are single-word only (no multi-word characters).
- Neutral brace tokens (`paren`, `angle`, `square`, `brace`) are retained, and explicit left/right ASCII brace symbols are also included under punctuation.
- Binary operator categories are intentionally empty for forward compatibility.

## Grammar (EBNF)

```ebnf
program = expression ;

expression =
      character [expression]
    | operator_call [expression]
    | special_bang [expression]
    ;

operator_call =
      unary_identifier_operator identifier
    | unary_character_operator character
    | binary_identifier_operator identifier identifier
    | binary_character_operator character character
    | nary_identifier_operator identifier+ special_bang
    | nary_character_operator character+ special_bang
    ;

special_bang = "blark" ;
```

## Lexical Sets

### Identifier

```ebnf
identifier = word_token ;
```

`identifier` is represented as a single lexical token (`word_token`) produced by tokenization.

### Character

```ebnf
character =
      letter_character
    | digit_character
    | punctuation_character
    | brace_character
    ;
```

#### Letter Characters

```ebnf
letter_character =
      "air"
    | "bat"
    | "cap"
    | "drum"
    | "each"
    | "fine"
    | "gust"
    | "harp"
    | "sit"
    | "jury"
    | "crunch"
    | "look"
    | "made"
    | "near"
    | "odd"
    | "pit"
    | "quench"
    | "red"
    | "sun"
    | "trap"
    | "urge"
    | "vest"
    | "whale"
    | "plex"
    | "yank"
    | "zip"
    ;
```

Notes:
- This set is the full Talon spoken alphabet.

#### Digit Characters

```ebnf
digit_character =
      "zero" | "one" | "two" | "three" | "four"
    | "five" | "six" | "seven" | "eight" | "nine"
    ;
```

#### Punctuation Characters

```ebnf
punctuation_character =
      "bang"
    | "doublequote"
    | "hash"
    | "dollar"
    | "percent"
    | "ampersand"
    | "apostrophe"
    | "star"
    | "plus"
    | "comma"
    | "dash"
    | "dot"
    | "quote"
    | "slash"
    | "colon"
    | "semicolon"
    | "less"
    | "equals"
    | "greater"
    | "question"
    | "at"
    | "backslash"
    | "caret"
    | "underscore"
    | "backtick"
    | "pipe"
    | "tilde"
    ;
```

#### Brace Characters

```ebnf
brace_character =
      "paren"
    | "angle"
    | "square"
    | "brace"
    ;
```

## Operators

### Unary Identifier Operators

```ebnf
unary_identifier_operator = "word" ;
```

### Unary Character Operators

```ebnf
unary_character_operator = "shift";
```

### Binary Identifier Operators

```ebnf
binary_identifier_operator = ;
```

Intentionally empty for future extension.

### Binary Character Operators

```ebnf
binary_character_operator = ;
```

Intentionally empty for future extension.

### N-ary Identifier Operators

```ebnf
nary_identifier_operator =
      "hammer"
    | "smash"
    | "camel"
    | "snake"
    | "kebab"
    | "dotted"
    | "conga"
    | "slasher"
    | "packed"
    | "constant"
    | "string"
    | "padded"
    ;
```

These follow Talon community formatter phrases from
`~/.talon/user/community/core/text/formatters.py` (`code_formatter_names`).

### N-ary Character Operators

```ebnf
nary_character_operator = ;
```

No n-ary character operators are currently defined.

## Parsing Implications

- `nary_*_operator` forms consume one or more arguments and terminate with `blark`.
- `expression` is right-recursive and can represent sequences.
- Because binary operator sets are empty, the corresponding `operator_call` alternatives are currently non-matching by design.
