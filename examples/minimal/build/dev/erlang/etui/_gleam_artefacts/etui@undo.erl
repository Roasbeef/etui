-module(etui@undo).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([undo_new/2, current/1, can_undo/1, can_redo/1, undo_depth/1, push/2, undo/1, redo/1, reset/2]).
-export_type([undo_stack/1]).

-type undo_stack(FXX) :: {undo_stack, list(FXX), FXX, list(FXX), integer()}.

-file("src/etui/undo.gleam", 42).
-spec undo_new(FXY, integer()) -> undo_stack(FXY).
-doc(~" Create a new stack with an initial `present` value.
 `max_size` limits how many past entries are retained (0 = unlimited).").
undo_new(Initial, Max_size) ->
    {undo_stack, [], Initial, [], Max_size}.

-file("src/etui/undo.gleam", 50).
-spec current(undo_stack(FYA)) -> FYA.
-doc(~" The current value.").
current(Stack) ->
    erlang:element(3, Stack).

-file("src/etui/undo.gleam", 55).
-spec can_undo(undo_stack(any())) -> boolean().
-doc(~" `True` if there is at least one past state to undo to.").
can_undo(Stack) ->
    not gleam@list:is_empty(erlang:element(2, Stack)).

-file("src/etui/undo.gleam", 60).
-spec can_redo(undo_stack(any())) -> boolean().
-doc(~" `True` if there is at least one future state to redo to.").
can_redo(Stack) ->
    not gleam@list:is_empty(erlang:element(4, Stack)).

-file("src/etui/undo.gleam", 65).
-spec undo_depth(undo_stack(any())) -> integer().
-doc(~" Number of past entries available to undo.").
undo_depth(Stack) ->
    erlang:length(erlang:element(2, Stack)).

-file("src/etui/undo.gleam", 74).
-spec push(undo_stack(FYI), FYI) -> undo_stack(FYI).
-doc(~" Record `new_value` as the new present, moving the old present into past.
 Clears the future (redo history) since the branch diverged.").
push(Stack, New_value) ->
    Past = [erlang:element(3, Stack) | erlang:element(2, Stack)],
    Trimmed = case (erlang:element(5, Stack) > 0) andalso (erlang:length(Past) > erlang:element(5, Stack)) of
        true ->
            gleam@list:take(Past, erlang:element(5, Stack));

        false ->
            Past
    end,
    {undo_stack, Trimmed, New_value, [], erlang:element(5, Stack)}.

-file("src/etui/undo.gleam", 90).
-spec undo(undo_stack(FYL)) -> undo_stack(FYL).
-doc(~" Undo: move present to future, restore the most-recent past as present.
 No-op if there is nothing to undo.").
undo(Stack) ->
    case erlang:element(2, Stack) of
        [] ->
            Stack;

        [Prev | Rest] ->
            {undo_stack, Rest, Prev, [erlang:element(3, Stack) | erlang:element(4, Stack)], erlang:element(5, Stack)}
    end.

-file("src/etui/undo.gleam", 105).
-spec redo(undo_stack(FYO)) -> undo_stack(FYO).
-doc(~" Redo: move present to past, restore the most-recent future as present.
 No-op if there is nothing to redo.").
redo(Stack) ->
    case erlang:element(4, Stack) of
        [] ->
            Stack;

        [Next | Rest] ->
            {undo_stack, [erlang:element(3, Stack) | erlang:element(2, Stack)], Next, Rest, erlang:element(5, Stack)}
    end.

-file("src/etui/undo.gleam", 119).
-spec reset(undo_stack(FYR), FYR) -> undo_stack(FYR).
-doc(~" Reset to initial state, clearing all history.").
reset(Stack, Initial) ->
    {undo_stack, [], Initial, [], erlang:element(5, Stack)}.

