<img width="360" height="553" alt="image" src="https://github.com/user-attachments/assets/bf124b7d-5d31-44bd-8931-1c33c40503c1" />

# Lambda Evaluator in Prolog

This project evaluates lambda-calculus-style expressions written as ASCII S-expressions.

This is a purely academic project intended for learning and historical exploration of lambda calculus, Lisp-style notation, Prolog, and symbolic AI ideas.

License: this project is released under [The Unlicense](https://unlicense.org) (public domain dedication).

It supports:
- `lambda` abstractions and application
- recursion via a Y-compatible combinator expression
- built-in arithmetic and comparisons on normal integers (not Church numerals)
- command-line evaluation from an input file
- multiple top-level forms with sequential `(define name expr)` bindings

## Historical context and timeline

This project sits at the intersection of two classic traditions in computer science:
- the lambda-calculus tradition (functions, substitution, recursion via fixed points)
- the logic-programming tradition (symbolic reasoning in Prolog)

Short timeline:
- 1930s: Alonzo Church develops lambda calculus as a formal model of computation.
- Late 1950s: John McCarthy creates Lisp, heavily influenced by lambda calculus; Lisp code and data are both S-expressions.
- 1972: Alain Colmerauer and Robert Kowalski develop Prolog, a language centered on symbolic logic, unification, and search.
- 1970s-1980s: Symbolic AI grows around languages like Lisp and Prolog for theorem proving, planning, expert systems, and knowledge representation.
- Today: Statistical and neural methods dominate many AI applications, but symbolic methods remain essential for explicit reasoning and interpretable structure.

Lambda calculus and Lisp connection:
- Lambda calculus provides the mathematical core for function abstraction/application.
- Lisp operationalized these ideas in a practical language with S-expression syntax and first-class functions.
- This evaluator follows that Lisp-like S-expression style while implementing lambda-calculus-style evaluation rules.

Why this matters for symbolic AI:
- Your evaluator manipulates symbols and structured expressions directly.
- Prolog provides a natural host for this because parsing, tree processing, and rule-based evaluation are all symbolic tasks.
- So this repo is a small, concrete bridge between historical symbolic AI ideas and executable modern code.

## Why SWI-Prolog in this project

SWI-Prolog is the concrete Prolog system used to run this evaluator.

How it figures into the implementation:
- Runtime engine: all evaluator predicates execute on SWI-Prolog.
- Parsing support: the project uses SWI-Prolog's DCG facilities and standard libraries to parse ASCII S-expressions.
- CLI execution: examples run with `swipl` from the shell, which makes the project easy to script.
- CI integration: GitHub Actions installs `swi-prolog-nox` and runs benchmark files automatically in the cloud.

Why this is a good fit:
- SWI-Prolog is mature, widely used, and easy to install on Linux and CI runners.
- It is strong at symbolic data processing, recursion, and tree transforms, exactly what an interpreter needs.
- It provides a practical bridge between classic symbolic AI ideas and modern tooling workflows (GitHub, CI, automation).

## Requirements

You need **SWI-Prolog** installed to run this project.

Ubuntu example:

```bash
sudo apt update
sudo apt install -y swi-prolog-nox
```

Then verify:

```bash
swipl --version
```

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

### Note on Y vs Z in this project

In `examples/fact5_define.lisp`, the value named `Y` is the strict-safe fixed-point style often called `Z`.

Why:
- Classical `Y` combinator:
  - `Y = λf.(λx.f (x x)) (λx.f (x x))`
  - Works naturally with non-strict (normal-order/lazy) evaluation.
- Strict/eager evaluators often try to evaluate `(x x)` too early, causing divergence.

The strict-safe variant delays self-reference by one lambda layer:
- `Z = λf.(λx.f (λv.((x x) v))) (λx.f (λv.((x x) v)))`

That extra `λv ...` postpones expansion until an argument is supplied, which is why recursion works robustly in practical evaluators like this one.

So, conceptually we demonstrate fixed-point recursion in the `Y` tradition, but operationally we use the `Z`-style form for reliability.

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
