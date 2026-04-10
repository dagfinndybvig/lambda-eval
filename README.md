# Lambda Evaluator in Prolog

This project evaluates lambda-calculus-style expressions written as ASCII S-expressions.

It supports:
- `lambda` abstractions and application
- recursion via a Y-compatible combinator expression
- built-in arithmetic and comparisons on normal integers (not Church numerals)
- command-line evaluation from an input file
- multiple top-level forms with sequential `(define name expr)` bindings

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

The evaluator reads one or more top-level forms per file.

Supported forms:
- Integer: `42`
- Variable/symbol: `x`
- Lambda: `(lambda (x) body)`
- Multi-arg lambda: `(lambda (x y z) body)` (desugared to nested lambdas)
- Application: `(f a)` or `(f a b c)` (left-associative)
- Conditional: `(if cond then else)` where non-zero is true and zero is false
- Top-level define: `(define name expr)` (evaluated sequentially)

Examples:

```lisp
(lambda (x) (* x x))
```

```lisp
((lambda (x) (+ x 1)) 4)
```

```lisp
(define square (lambda (x) (* x x)))
(square 6)
```

`define` semantics:
- forms are processed top-to-bottom
- each define is evaluated and bound for subsequent forms
- the value printed is the value of the last non-define expression form

## Built-in primitives

These symbols are built in:
- `+`, `-`, `*`, `/` (integer division)
- `=`, `<`, `>`, `<=`, `>=`

Comparisons return integers:
- true -> `1`
- false -> `0`

This makes them work naturally with `(if ...)`.

## Benchmark: factorial with combinator recursion

`examples/fact5.lisp` computes factorial of `5` as one expression.

`examples/fact5_define.lisp` computes factorial of `5` using `define` forms:

```lisp
(define Y
  (lambda (f)
    ((lambda (x) (f (lambda (v) ((x x) v))))
     (lambda (x) (f (lambda (v) ((x x) v))))))
)

(define fact
  (Y
    (lambda (fact)
      (lambda (n)
        (if (= n 0)
            1
            (* n (fact (- n 1)))))))
)

(fact 5)
```

It also evaluates to:

```text
120
```

The single-expression version:

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

2. Parse S-expressions into forms
- A DCG parser tokenizes/parses the source into intermediate S-expression nodes (`int`, `sym`, `list`).
- Top-level forms are converted to:
  - `define(Name, Expr)` for `(define name expr)`
  - `expr(Expr)` for ordinary expressions

3. Convert expressions to AST
- Expression S-expressions are transformed into evaluator AST:
  - `int(N)`
  - `var(Name)`
  - `lam(Param, Body)`
  - `app(Fn, Arg)`
  - `if(Cond, Then, Else)`
- Multi-argument lambdas and applications are desugared into nested unary forms.

4. Evaluate forms sequentially
- `define` forms are evaluated in order, extending the environment.
- Expression forms are evaluated in the current environment.
- The final expression value is printed.

5. Evaluate expressions with lexical scope
- `eval/3` evaluates expressions in an environment.
- Lambdas evaluate to closures: `closure(Param, Body, Env)`.
- Application of closures binds the argument as a thunk (`thunk(Expr, Env)`), giving non-strict/call-by-name behavior.

6. Why recursion combinators work
- Non-strict argument handling avoids immediate infinite self-expansion.
- That enables fixed-point combinator style recursion for practical examples like factorial.

7. Primitive arithmetic execution
- Primitive symbols are recognized as builtins.
- Builtins are curried internally and consume evaluated integer arguments.
- Results are wrapped as `int(N)`.

8. Print result
- Integers print as plain numbers (e.g., `120`).
- Non-integer values print in Prolog-readable form.

## Public predicates

- `run_file(+Path)`  
  Parse and evaluate one expression from file, then print result.

- `parse_file(+Path, -Expr)`  
  Parse file into internal AST.

- `eval_expr(+Expr, -Value)`  
  Evaluate AST to a value.
