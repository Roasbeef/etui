-module(etui@backend@default).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([new/0, new_with_mouse/0, new_with_options/1]).

-file("src/etui/backend/default.gleam", 23).
-spec new() -> etui@backend:backend(etui@backend@erlang:erlang_terminal_state()).
new() ->
    etui@backend@erlang:new().

-file("src/etui/backend/default.gleam", 28).
-spec new_with_mouse() -> etui@backend:backend(etui@backend@erlang:erlang_terminal_state()).
new_with_mouse() ->
    etui@backend@erlang:new_with_mouse().

-file("src/etui/backend/default.gleam", 34).
-spec new_with_options(etui@backend:options()) -> etui@backend:backend(etui@backend@erlang:erlang_terminal_state()).
-doc(~" Backend with an explicit feature set. Same call on both targets.").
new_with_options(Opts) ->
    etui@backend@erlang:new_with_options(Opts).

