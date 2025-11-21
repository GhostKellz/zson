# ZSON Specification v0.1

**ZSON** (ZigScript Object Notation) - A superset of JSON designed for ZigScript with developer-friendly syntax.

## Design Goals

1. **100% JSON Compatible** - Every valid JSON is valid ZSON
2. **Human-Friendly** - Comments, trailing commas, unquoted keys
3. **Type Hints** - Optional type annotations for ZigScript integration
4. **Simple** - Easy to parse, minimal surprises

## Features Beyond JSON

### 1. Comments

```zson
{
  // Single-line comments
  "name": "Alice",

  /* Multi-line
     comments */
  "age": 30
}
```

### 2. Trailing Commas

```zson
{
  "items": [1, 2, 3,],  // Trailing comma OK
  "extra": true,         // Trailing comma OK
}
```

### 3. Unquoted Keys

Keys can be unquoted if they're valid identifiers:

```zson
{
  name: "Alice",           // Unquoted key
  age: 30,
  is_active: true,
  "special-key": "quoted"  // Needs quotes due to hyphen
}
```

### 4. Single-Quoted Strings

```zson
{
  name: 'Alice',           // Single quotes work
  message: "Hello \"world\"",  // Or double quotes
}
```

### 5. Multiline Strings

```zson
{
  bio: """
    This is a multiline string.
    It preserves line breaks.
    Great for long text.
  """
}
```

### 6. Type Hints (Optional)

For ZigScript integration:

```zson
{
  id: 42 @i32,             // Type hint
  score: 98.5 @f64,
  name: "Alice" @string,
  items: [1, 2, 3] @[i32]
}
```

### 7. Hex/Binary Numbers

```zson
{
  color: 0xFF00FF,         // Hex
  flags: 0b10101010,       // Binary
  normal: 255              // Decimal
}
```

### 8. Special Values

```zson
{
  infinity: Infinity,
  neg_inf: -Infinity,
  not_a_num: NaN,
  nothing: null,
  undefined: undefined     // ZigScript undefined
}
```

## Grammar (Informal)

```
zson_value := object | array | string | number | boolean | null

object := '{' (pair (',' pair)* ','?)? '}'
pair   := key ':' zson_value
key    := identifier | string

array := '[' (zson_value (',' zson_value)* ','?)? ']'

string := '"' chars '"' | "'" chars "'" | '"""' multiline '"""'
number := integer | float | hex | binary
boolean := 'true' | 'false'
null := 'null' | 'undefined'

identifier := [a-zA-Z_][a-zA-Z0-9_]*

comment := '//' .*? '\n' | '/*' .*? '*/'
```

## ZSON vs JSON

| Feature | JSON | ZSON |
|---------|------|------|
| Comments | ❌ | ✅ |
| Trailing commas | ❌ | ✅ |
| Unquoted keys | ❌ | ✅ |
| Single quotes | ❌ | ✅ |
| Multiline strings | ❌ | ✅ |
| Type hints | ❌ | ✅ |
| Hex/Binary | ❌ | ✅ |
| Infinity/NaN | ❌ | ✅ |

## Examples

### Simple Config

```zson
{
  // App configuration
  app: {
    name: "MyApp",
    version: "1.0.0",
    debug: true,
  },

  database: {
    host: "localhost",
    port: 5432,
    max_connections: 100,
  },
}
```

### API Response

```zson
{
  status: 200,
  data: {
    users: [
      {id: 1, name: "Alice", active: true},
      {id: 2, name: "Bob", active: false},
    ],
    total: 2,
  },
  meta: {
    timestamp: 1700000000,
    version: "v2",
  },
}
```

### With Type Hints

```zson
{
  user_id: 42 @i32,
  score: 98.5 @f64,
  name: "Alice" @string,
  tags: ["dev", "admin"] @[string],

  settings: {
    theme: "dark",
    notifications: true,
  } @UserSettings,
}
```

## Implementation Notes

- Whitespace is ignored (except in strings)
- Comments are stripped during parsing
- Type hints are optional metadata, not enforced by parser
- Numbers default to f64 unless type hint specifies otherwise
- Multiline strings trim leading/trailing whitespace from each line

## Conversion

**ZSON → JSON:**
- Strip comments
- Remove trailing commas
- Quote all keys
- Convert single quotes to double quotes
- Remove type hints
- Convert special values (Infinity → null or error)

**JSON → ZSON:**
- Valid JSON is already valid ZSON
- Can optionally format with unquoted keys, etc.

## File Extension

- **Strict ZSON**: `.zson`
- **JSON compatible**: `.json` (still parseable as ZSON)

## Version

Current: **v0.1.0** (Phase 1)

Next: Type validation, schema support, custom extensions
