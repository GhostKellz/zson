# ZSON Specification v0.1.0

ZSON is a strict superset of JSON. All valid JSON is valid ZSON.

## Values

### Objects

```zson
{
  key: "value",
  "quoted key": 123,
}
```

- Keys can be unquoted if they are valid identifiers
- Trailing commas are allowed
- Reserved words (`true`, `false`, `null`, `undefined`, `Infinity`, `NaN`) must be quoted as keys

### Arrays

```zson
[1, 2, 3,]
```

- Trailing commas are allowed

### Strings

```zson
"double quoted"
'single quoted'
"""
multiline
string
"""
```

#### Escape Sequences

| Sequence | Character |
|----------|-----------|
| `\\` | Backslash |
| `\"` | Double quote |
| `\'` | Single quote |
| `\n` | Newline |
| `\r` | Carriage return |
| `\t` | Tab |
| `\b` | Backspace |
| `\f` | Form feed |
| `\/` | Forward slash |
| `\uXXXX` | Unicode (4 hex digits) |

### Numbers

```zson
42          // Integer
-17         // Negative
3.14        // Float
1.5e10      // Scientific
0xFF        // Hexadecimal
0b1010      // Binary
0o755       // Octal
Infinity    // Positive infinity
-Infinity   // Negative infinity
NaN         // Not a number
```

### Booleans

```zson
true
false
```

### Null Values

```zson
null
undefined
```

## Comments

```zson
{
  // Single-line comment
  key: "value",

  /* Multi-line
     comment */
  other: 123,
}
```

## Type Hints

Type hints are parsed but not enforced (metadata only):

```zson
{
  port: 8080 @i32,
  name: "app" @string,
  flags: [1, 2, 3] @[i32],
}
```

## Grammar

```ebnf
value     = object | array | string | number | boolean | null ;
object    = "{" [ member { "," member } [ "," ] ] "}" ;
member    = key ":" value [ type_hint ] ;
key       = identifier | string ;
array     = "[" [ value { "," value } [ "," ] ] "]" ;
string    = dquote | squote | multiline ;
number    = integer | float | hex | binary | octal | special ;
boolean   = "true" | "false" ;
null      = "null" | "undefined" ;
type_hint = "@" identifier [ "[" identifier "]" ] ;
comment   = "//" ... newline | "/*" ... "*/" ;
```

## Compatibility

- All valid JSON documents are valid ZSON
- ZSON can be converted to JSON with `toJson()`
- JSON mode disables: unquoted keys, trailing commas, single quotes
