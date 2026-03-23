#set heading(numbering: "I.A.i.a.")
// rect for making grid stand out
#set rect(
  fill: luma(230),
  inset: 8pt,
  width: 100%,
)

= Dead code elimination

Was pretty straightforward, didn't take notes before implementing.

= Local value numbering

== Three basically same optimizations.

All three can be characterized as:
- no change from initial value to usage or
- merge back operations.

#grid(columns: (1fr, 1fr, 1fr), gutter: 3pt,

rect[
1) dead code elimination
```asm
main {
  a: int = const 100;
  a: int = const 42
  print a;
}
```
becomes
```asm
main {
  a: int = const 100;
  print a;
}
```
],
rect[
2) copy propagation
```asm
main {
  x: int = const 4;
  copy1: int = id x;
  copy2: int = id copy1;
  copy3: int = id copy2;
  print copy3;
}
```
becomes
```asm
main {
  x: int = const 4;
  print x;
}
```
],
rect[
3) common subexpression elimination (cse)
```asm
main {
  a: int = const 4;
  b: int = const 2;
  sum1: int = add a b;
  sum2: int = add a b;
  prod: int = mul sum1 sum2;
  print prod;
}
```
(`(a + b)` is a common subexpression.)
becomes
```asm
  a: int = const 4;
  b: int = const 2;
  sum1: int = add a b;
  prod: int = mul sum1 sum1;
  print prod;
```
])

== Disambiguate values from variables

Prof frames as "look at values being computed, instead of variables"

#grid(columns: (1fr, 1fr, 1fr), gutter: 3pt,

rect[
1) dead code elimination
```asm
main {
  a: int = const 100;
  a: int = const 42
  print a;
}
```
*Var* = `a`. *Val* = `100` and `42`.
],
rect[
2) copy propagation
```asm
main {
  x: int = const 4;
  copy1: int = id x;
  copy2: int = id copy1;
  copy3: int = id copy2;
  print copy3;
}
```
*Var* = `x`, `copy1`, `copy2`, `copy3`. *Val* = 4.
],
rect[
3) common subexpression elimination (cse)
```asm
main {
  a: int = const 4;
  b: int = const 2;
  sum1: int = add a b;
  sum2: int = add a b;
  prod: int = mul sum1 sum2;
  print prod;
}
```
*Var* = `a`, `b`, `sum1`, `sum2`, `prod`. *Val* = `4`, `2`.
])
