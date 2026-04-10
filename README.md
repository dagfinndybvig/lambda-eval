# Lambda Evaluator in Prolog

This project evaluates lambda-calculus-style expressions written as ASCII S-expressions.

It supports:
- `lambda` abstractions and application
- recursion via a Y-compatible combinator expression
- built-in arithmetic and comparisons on normal integers (not Church numerals)
- command-line evaluation from an input file

## Quick start

From the project directory:

```bash
swipl -q -s lambda_eval.pl -g "run_file('examples/fact5.lisp'),halt."
```

Expected output:

```text
120
```

## Input format (S-expressions)

The evaluator reads one expression per file.

Supported forms:
- Integer: `42`
- Variable/symbol: `x`
- Lambda: `(lambda (x) body)`
- Multi-arg lambda: `(lambda (x y z) body)` (desugared to nested lambdas)
- Application: `(f a)` or `(f a b c)` (left-associative)
- Conditional: `(if cond then else)` where non-zero is true and zero is false

Examples:

```lisp
(lambda (x) (* x x))
```

```lisp
((lambda (x) (+ x 1)) 4)
```

## Built-in primitives

These symbols are built in:
- `+`, `-`, `*`, `/` (integer division)
- `=`, `<`, `>`, `<=`, `>=`

Comparisons return integers:
- true -> `1`
- false -> `0`

This makes them work naturally with `(if ...)`.

## Benchmark: factorial with combinator recursion

`examples/fact5.lisp` computes factorial of `5` using a fixed-point combinator pattern:

```lisp
(
  (lambda (Y)
    ((Y
      (lambda (fact)
        (lambda (n)
          (if (= n 0)
              1
              (* n (fact (- n 1)))))))
     5))
  (lambda (f)
    ((lambda (x) (f (lambda (v) ((x x) v))))
     (lambda (x) (f (lambda (v) ((x x) v))))))
)
```

Evaluates to:

```text
120
```

## How it works logically

The implementation is in `lambda_eval.pl` and follows this pipeline:

1. Read file text
- `run_file/1` reads the ASCII file into a string.

2. Parse S-expression
- A DCG parser tokenizes/parses the source into an intermediate S-expression tree (`int`, `sym`, `list`).

3. Convert to AST
- S-expression is transformed into evaluator AST:
  - `int(N)`
  - `var(Name)`
  - `lam(Param, Body)`
  - `app(Fn, Arg)`
  - `if(Cond, Then, Else)`
- Multi-argument lambdas and applications are desugared into nested unary forms.

4. Evaluate with lexical scope
- `eval/3` evaluates expressions in an environment.
- Lambdas evaluate to closures: `closure(Param, Body, Env)`.
- Application of closures binds the argument as a thunk (`thunk(Expr, Env)`), giving non-strict/call-by-name behavior.

5. Why recursion combinators work
- Non-strict argument handling avoids immediate infinite self-expansion.
- That enables fixed-point combinator style recursion for practical examples like factorial.

6. Primitive arithmetic execution
- Primitive symbols are recognized as builtins.
- Builtins are curried internally and consume evaluated integer arguments.
- Results are wrapped as `int(N)`.

7. Print result
- Integers print as plain numbers (e.g., `120`).
- Non-integer values print in Prolog-readable form.

## Public predicates

- `run_file(+Path)`  
  Parse and evaluate one expression from file, then print result.

- `parse_file(+Path, -Expr)`  
  Parse file into internal AST.

- `eval_expr(+Expr, -Value)`  
  Evaluate AST to a value.
