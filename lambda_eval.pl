:- module(lambda_eval, [run_file/1, parse_file/2, eval_expr/2]).

:- use_module(library(dcg/basics)).
:- use_module(library(readutil)).

run_file(Path) :-
    parse_file(Path, Expr),
    eval_expr(Expr, Value),
    print_value(Value).

parse_file(Path, Expr) :-
    read_file_to_string(Path, Source, []),
    string_codes(Source, Codes),
    phrase(program(SExpr), Codes),
    sexpr_to_ast(SExpr, Expr).

eval_expr(Expr, Value) :-
    eval(Expr, [], Value).

print_value(int(N)) :-
    format('~w~n', [N]).
print_value(Value) :-
    format('~q~n', [Value]).

program(SExpr) -->
    ws,
    sexpr(SExpr),
    ws,
    eos.

sexpr(int(N)) -->
    integer(N),
    !.
sexpr(sym(A)) -->
    symbol_codes(Codes),
    { atom_codes(A, Codes) }.
sexpr(list(Items)) -->
    "(",
    ws,
    sexpr_list(Items),
    ws,
    ")".

sexpr_list([X|Xs]) -->
    sexpr(X),
    ws,
    !,
    sexpr_list(Xs).
sexpr_list([]) -->
    [].

symbol_codes([C|Cs]) -->
    [C],
    { \+ code_type(C, space), C \= 0'(, C \= 0') },
    symbol_codes_rest(Cs).

symbol_codes_rest([C|Cs]) -->
    [C],
    { \+ code_type(C, space), C \= 0'(, C \= 0') },
    !,
    symbol_codes_rest(Cs).
symbol_codes_rest([]) -->
    [].

ws -->
    [C],
    { code_type(C, space) },
    !,
    ws.
ws -->
    ";" ,
    string_without("\n", _),
    ( "\n" ; eos ),
    !,
    ws.
ws -->
    [].

sexpr_to_ast(int(N), int(N)).
sexpr_to_ast(sym(A), var(A)).
sexpr_to_ast(list([sym(lambda), list(Params), BodySExpr]), Expr) :-
    params_atoms(Params, ParamAtoms),
    sexpr_to_ast(BodySExpr, BodyExpr),
    lambdas_from_params(ParamAtoms, BodyExpr, Expr).
sexpr_to_ast(list([sym(if), CondS, ThenS, ElseS]), if(Cond, Then, Else)) :-
    sexpr_to_ast(CondS, Cond),
    sexpr_to_ast(ThenS, Then),
    sexpr_to_ast(ElseS, Else).
sexpr_to_ast(list([Head|Tail]), AppExpr) :-
    Tail \= [],
    sexpr_to_ast(Head, HeadExpr),
    maplist(sexpr_to_ast, Tail, TailExprs),
    foldl(apply_node, TailExprs, HeadExpr, AppExpr).
sexpr_to_ast(list([]), _) :-
    throw(error(syntax_error(empty_application), _)).

params_atoms([], []).
params_atoms([sym(A)|Rest], [A|AtomsRest]) :-
    params_atoms(Rest, AtomsRest).
params_atoms([Other|_], _) :-
    throw(error(type_error(lambda_parameter_symbol, Other), _)).

lambdas_from_params([], Body, Body).
lambdas_from_params([P|Ps], Body, lam(P, Rest)) :-
    lambdas_from_params(Ps, Body, Rest).

apply_node(Arg, Fn, app(Fn, Arg)).

eval(int(N), _, int(N)).
eval(var(Name), Env, Value) :-
    (   lookup_env(Name, Env, Binding)
    ->  force(Binding, Value)
    ;   builtin_arity(Name, Arity)
    ->  Value = builtin(Name, Arity, [])
    ;   throw(error(existence_error(variable, Name), _))
    ).
eval(lam(Param, Body), Env, closure(Param, Body, Env)).
eval(if(Cond, Then, Else), Env, Value) :-
    eval(Cond, Env, CondValue),
    expect_int(CondValue, CondN),
    (   CondN =\= 0
    ->  eval(Then, Env, Value)
    ;   eval(Else, Env, Value)
    ).
eval(app(FnExpr, ArgExpr), Env, Value) :-
    eval(FnExpr, Env, FnValue),
    apply_value(FnValue, ArgExpr, Env, Value).

lookup_env(Name, [Name-Binding|_], Binding) :- !.
lookup_env(Name, [_|Rest], Binding) :-
    lookup_env(Name, Rest, Binding).
lookup_env(_, [], _) :-
    fail.

force(thunk(Expr, Env), Value) :-
    eval(Expr, Env, Value).
force(value(Value), Value).

apply_value(closure(Param, Body, ClosureEnv), ArgExpr, CallEnv, Value) :-
    eval(Body, [Param-thunk(ArgExpr, CallEnv)|ClosureEnv], Value).
apply_value(builtin(Name, Arity, Args), ArgExpr, CallEnv, Value) :-
    append(Args, [thunk(ArgExpr, CallEnv)], NewArgs),
    length(NewArgs, Len),
    (   Len < Arity
    ->  Value = builtin(Name, Arity, NewArgs)
    ;   Len =:= Arity
    ->  run_builtin(Name, NewArgs, Value)
    ;   throw(error(arity_error(Name/Arity), _))
    ).
apply_value(Value, _, _, _) :-
    throw(error(type_error(applicable, Value), _)).

builtin_arity('+', 2).
builtin_arity('-', 2).
builtin_arity('*', 2).
builtin_arity('/', 2).
builtin_arity('=', 2).
builtin_arity('<', 2).
builtin_arity('>', 2).
builtin_arity('<=', 2).
builtin_arity('>=', 2).

run_builtin(Name, [AThunk, BThunk], int(Result)) :-
    force(AThunk, AV),
    force(BThunk, BV),
    expect_int(AV, A),
    expect_int(BV, B),
    run_builtin_int(Name, A, B, Result).

run_builtin_int('+', A, B, R) :- R is A + B.
run_builtin_int('-', A, B, R) :- R is A - B.
run_builtin_int('*', A, B, R) :- R is A * B.
run_builtin_int('/', A, B, R) :- R is A // B.
run_builtin_int('=', A, B, 1) :- A =:= B, !.
run_builtin_int('=', _, _, 0).
run_builtin_int('<', A, B, 1) :- A < B, !.
run_builtin_int('<', _, _, 0).
run_builtin_int('>', A, B, 1) :- A > B, !.
run_builtin_int('>', _, _, 0).
run_builtin_int('<=', A, B, 1) :- A =< B, !.
run_builtin_int('<=', _, _, 0).
run_builtin_int('>=', A, B, 1) :- A >= B, !.
run_builtin_int('>=', _, _, 0).

expect_int(int(N), N) :- !.
expect_int(V, _) :-
    throw(error(type_error(integer_value, V), _)).
