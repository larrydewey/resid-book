---
title: Numbers
description: The page that proves code fences and tables render.
---

Money is an exact `Dec(N)`: N significant decimal digits, never a binary
float.

| Type | Family | Notes |
|---|---|---|
| `Int(8)`..`Int(512)` | integers | every width checked |
| `UInt(N)` | unsigned | same widths |
| `Float(16)`..`Float(128)` | binary floats | `precision` applies here |
| `Dec(N)` | decimals | exact, no NaN or Inf |

## Arithmetic

```resid
Dec(4) a = 12.34m;
Dec(4) b = 0.3000m;
Dec main() {
    println(f"{a + b}");
    return 0;
}
```

```text title="Output"
12.64
```

## Shell

```sh
$ residc src/site.resid -o resid-book -depmap deps.txt
$ ./resid-book examples/sample/book.toml
```

## JSON

```json
{ "title": "Sample Book", "pages": 3 }
```