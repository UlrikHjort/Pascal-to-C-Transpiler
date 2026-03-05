# pascal2c - Pascal to C Transpiler

A Pascal-to-C transpiler written mostly in **Ada**, using **Flex** and **Bison**
for lexing and parsing.  The transpiler follows a three-pass -
**parse -> type-check -> code-generate** - with all semantic passes implemented in
Ada.  The generated C is compiled with any standard C11 compiler.

```
source.pas -> bin/pascal2c - > source.c ->  gcc - > runnable program

```

[Architecture Details](ARCHITECTURE.md)

## Dependencies

| Tool | Purpose |
|------|---------|
| `gnat` / `gnatmake` | Ada compiler |
| `flex` | Lexer generator |
| `bison` | Parser generator |
| `gcc` | Compile generated C files |

---


## Make targets

```bash
make                  # build bin/pascal2c and run all tests
make transpile        # Pascal -> C for every example  (-> c_src/*.c)
make compile-c        # C -> binary for every example  (-> output/*)
make test             # run output/* and diff against examples/*.expected
make test-features    # run feature unit tests from tests/
make demos            # build interactive demos in demos/  (-> output/*)
make clean            # remove build/, bin/, c_src/, output/
```

Adding a new regression test is automatic: drop `examples/myprog.pas` +
`examples/myprog.expected` and re-run `make`.

For tests that require stdin input, add `tests/myprog.input` - the test runner
will pipe it automatically.

---

## Manual use

```bash
# Transpile one file
./bin/pascal2c hello.pas hello.c

# Compile the generated C
gcc -std=c11 -D_POSIX_C_SOURCE=200809L -Iinclude hello.c -o hello -lm

# Run
./hello
```

---

## Supported Pascal features

### Types

| Pascal | Generated C | Notes |
|--------|-------------|-------|
| `integer` | `int` | |
| `real` | `double` | |
| `boolean` | `int` (0/1) | literals `true`/`false`; prints `TRUE`/`FALSE` |
| `char` | `char` | single-char literals emit C `'x'` |
| `string` | `char *` | unbounded heap string |
| `string[N]` | `char[N+1]` | fixed capacity; assignment uses `strncpy` |
| `array[m..n] of T` | `T name[n-m+1]` | 1-D; bounds from literals, consts, or `CONST±LIT` |
| `array[m..n, p..q, …] of T` | `T name[…][…]` | multi-dimensional (any number of dims) |
| `^T` | `T *` | pointer; `new`/`dispose` supported |
| `record … end` | `struct { … }` | |
| `record … case tag: T of … end` | `struct { … union { struct{…}; … } }` | variant record (C11 anonymous union/structs) |
| `set of T` | `uint64_t` | bitmask; elements must be 0–63 |
| subrange `lo..hi` | base type | validated at parse time |
| enumeration `(A,B,C)` | `enum { A,B,C }` | `ord`, `succ`, `pred` work |
| `text` | `pascal_file_t` | wraps `FILE *`; full file I/O API |
| `type Fn = function(…):T` | `typedef T (*Fn)(…)` | procedural type (function pointer) |

### Declarations

| Feature | Example |
|---------|---------|
| Constants | `const Max = 100;  Msg = 'hi';  N = Max*2+1;` |
| Typed constants | `const A: array[1..3] of integer = (2,3,5);` - mutable, emitted as `static` |
| Types | `type Color = (Red,Green,Blue);  Point = record x,y:real end;` |
| Variables | `var x, y: integer;  s: string[20];` |
| Functions | `function Max(a,b:integer):integer; begin Max := … end;` |
| Procedures | `procedure Greet(s:string); begin writeln(s) end;` |
| `var` parameters | `procedure Swap(var a, b: integer);` |
| Forward declarations | `function IsEven(n:integer):boolean; forward;` |
| Nested functions | declared inside other functions (GCC nested-function extension) |
| `label` / `goto` | `label 100; … 100: stmt; … goto 100;` |
| Procedural variables | `var f: MathFn;  f := @Sin;  writeln(f(1.0));` |
| Units | `unit Foo; interface … implementation … end.` + `uses Foo;` |

### Statements

| Feature | Example |
|---------|---------|
| Assignment | `x := expr` |
| `if / then / else` | dangling-else resolved correctly |
| `while / do` | |
| `for / to / downto` | `for i := 1 to 10 do` |
| `for i in lo..hi do` | range-for without explicit init |
| `repeat / until` | |
| `case … of … else … end` | integer, char, range arms (`'a'..'z':`) |
| `with … do` | resolves record fields in scope |
| `begin … end` | compound statement |
| `break` / `continue` | innermost loop control |
| `exit` / `exit(expr)` | return from routine |
| `halt` / `halt(n)` | exit program with code |
| `try … except … end` | exception handling via setjmp/longjmp |
| `try … finally … end` | guaranteed cleanup |
| `raise expr` | raise with message string |
| `on E: Exception do` | typed handler - `E` bound to message |
| File I/O | `assign`, `rewrite`, `reset`, `close`, `writeln(f,x)`, `readln(f,x)`, `eof(f)` |

### Operators

| Category | Operators |
|----------|-----------|
| Arithmetic | `+  -  *  /  div  mod` |
| Bitwise | `shl  shr  xor` |
| Relational | `=  <>  <  >  <=  >=` |
| Boolean | `and  or  not` |
| String | `+` (concatenation) |
| String compare | `=  <>  <  >  <=  >=` - `strcmp`-based |
| Set | `+` union, `-` difference, `*` intersection, `in` membership |
| Address-of | `@func` - produces function pointer |

### I/O

| Feature | Example |
|---------|---------|
| `write` / `writeln` | any number of args, any type |
| Field width | `writeln(x:8)` -> `printf("%8d",x)` |
| Width + precision | `writeln(f:10:3)` -> `printf("%10.3f",f)` |
| `read(x)` | read value from stdin, no line flush |
| `readln(x)` | read value from stdin, flush to end of line |
| `readln(x,y,z)` | read multiple values, then flush |
| `readln` | flush (skip) current input line |
| `readln(f,x)` | read from text file |

### Built-in routines

| Category | Names |
|----------|-------|
| Math | `abs`, `sqr`, `sqrt`, `sin`, `cos`, `ln`, `exp`, `round`, `trunc`, `frac`, `odd` |
| Conversion | `ord`, `chr`, `succ`, `pred`, `float`, `integer` |
| String (fn) | `length`, `copy(s,pos,len)`, `concat`, `pos(sub,s)`, `upcase`, `lowercase`, `uppercase`, `trim` |
| String (proc) | `delete(s,pos,n)`, `insert(sub,s,pos)`, `str(n,s)`, `val(s,n,code)` |
| String <-> num | `inttostr`, `strtoint`, `floattostr`, `strtofloat`, `formatfloat(fmt,x)` |
| Memory | `new(p)`, `dispose(p)` |
| Control | `halt`, `halt(code)`, `exit`, `exit(value)` |
| Inc/Dec | `inc(x)`, `inc(x,n)`, `dec(x)`, `dec(x,n)` |
| File | `eof(f)`, `eoln(f)` |
| Random | `randomize`, `random` (-> real 0..1), `random(n)` (-> int 0..n-1) |
| Terminal | `clrscr`, `gotoxy(x,y)`, `delay(ms)`, `textcolor(n)`, `hidecursor`, `showcursor` |
| Raw input | `keypressed` (bool), `readkey` (char), `rawmode`, `normalmode` |

### ANSI colour constants

`pascal_runtime.h` defines ANSI escape macros usable directly in `write`/`writeln`:

```pascal
writeln(ANSI_RED, 'Error!', ANSI_RESET);
```

Available: `ANSI_RESET`, `ANSI_BLACK`, `ANSI_RED`, `ANSI_GREEN`, `ANSI_YELLOW`,
`ANSI_BLUE`, `ANSI_MAGENTA`, `ANSI_CYAN`, `ANSI_WHITE`, and bright variants
`ANSI_BRED` … `ANSI_BWHITE`.  `textcolor(n)` uses Turbo-Pascal-style codes 0–15.

---

## Examples

The `examples/` directory contains 27 programs covering the full feature set,
each with a `.expected` output file verified by `make test`.

The `tests/` directory contains 20 focused unit tests for individual language
features (bitops, goto/label, variant records, procedural types, typed constants,
readln, string builtins, …).

---

## Demo programs

All demos require an ANSI-capable terminal.  Build with `make demos`, run from
`output/`.

| Demo | Description |
|------|-------------|
| `mandelbrot` | Mandelbrot set in ASCII with 16-colour gradient |
| `gameoflife` | Conway's Game of Life, 60×30 grid, 80 ms tick |
| `fallingtiles` | Falling-blocks game: 7 shapes, line-clear, score; **space** = hard drop |
| `snake` | Classic Snake with food and score; `wasd` to steer |
| `sortviz` | Animated bubble sort with ANSI colour bars |
| `calculator` | Interactive 4-op calculator using `readln` |
| `guessing` | Number guessing game using `readln` + `random` |

---

## Error reporting

The type-checker writes diagnostics to **stderr** with source line numbers:

```
line 5: error: undeclared identifier 'foo'
line 12: warning: undeclared function 'bar'
line 18: warning: type mismatch in assignment
```

The parser uses Bison error-recovery tokens to continue after syntax errors so
multiple problems are reported in a single run.  If any **error** is detected,
`pascal2c` exits with code **1** and does not write the output file.  Warnings
do not affect the exit status.

---

## Known limitations

- Set elements must fit in bits 0–63 (`uint64_t` bitmask)
- `case` selectors must be ordinal types (integer, char, boolean, enum) - this
  matches the ISO 7185 Pascal standard; `case` on string or real is not valid
  Pascal in any standard compiler
- Nested functions use GCC's nested-function extension (not portable to clang/MSVC)
- No object-oriented extensions (classes, inheritance) - deliberately; those are
  not part of ISO 7185 standard Pascal

