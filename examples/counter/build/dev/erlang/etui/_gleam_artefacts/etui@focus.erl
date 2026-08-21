-module(etui@focus).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([focus_new/1, focused/1, is_focused/2, current_index/1, size/1, focus_next/1, focus_prev/1, focus_id/2, focus_index/2]).
-export_type([focus_ring/0]).

-type focus_ring() :: {focus_ring, list(binary()), integer()}.

-file("src/etui/focus.gleam", 37).
-spec focus_new(list(binary())) -> focus_ring().
-doc(~" Create a focus ring from a list of slot IDs.
 The first slot starts focused. Empty list creates an inert ring.").
focus_new(Ids) ->
    {focus_ring, Ids, 0}.

-file("src/etui/focus.gleam", 116).
-spec get_at(list(binary()), integer()) -> {ok, binary()} | {error, nil}.
get_at(Lst, Idx) ->
    case Idx of
        I when I < 0 ->
            {error, nil};

        0 ->
            case Lst of
                [H | _] ->
                    {ok, H};

                [] ->
                    {error, nil}
            end;

        _ ->
            case Lst of
                [] ->
                    {error, nil};

                [_ | Rest] ->
                    get_at(Rest, Idx - 1)
            end
    end.

-file("src/etui/focus.gleam", 45).
-spec focused(focus_ring()) -> {ok, binary()} | {error, nil}.
-doc(~" ID of the currently focused slot, or `None` if the ring is empty.").
focused(Ring) ->
    get_at(erlang:element(2, Ring), erlang:element(3, Ring)).

-file("src/etui/focus.gleam", 50).
-spec is_focused(focus_ring(), binary()) -> boolean().
-doc(~" `True` if `id` is the currently focused slot.").
is_focused(Ring, Id) ->
    case focused(Ring) of
        {ok, Current_id} ->
            Current_id =:= Id;

        {error, _} ->
            false
    end.

-file("src/etui/focus.gleam", 58).
-spec current_index(focus_ring()) -> integer().
-doc(~" 0-based index of the currently focused slot.").
current_index(Ring) ->
    erlang:element(3, Ring).

-file("src/etui/focus.gleam", 63).
-spec size(focus_ring()) -> integer().
-doc(~" Total number of slots in the ring.").
size(Ring) ->
    erlang:length(erlang:element(2, Ring)).

-file("src/etui/focus.gleam", 143).
-spec unwrap_zero({ok, integer()} | {error, nil}) -> integer().
unwrap_zero(R) ->
    case R of
        {ok, N} ->
            N;

        {error, _} ->
            0
    end.

-file("src/etui/focus.gleam", 71).
-spec focus_next(focus_ring()) -> focus_ring().
-doc(~" Move focus to the next slot (wraps around).").
focus_next(Ring) ->
    N = erlang:length(erlang:element(2, Ring)),
    case N of
        0 ->
            Ring;

        _ ->
            {focus_ring, erlang:element(2, Ring), begin
                _pipe = erlang:element(3, Ring) + 1,
                _pipe@1 = gleam@int:modulo(_pipe, N),
                unwrap_zero(_pipe@1)
            end}
    end.

-file("src/etui/focus.gleam", 84).
-spec focus_prev(focus_ring()) -> focus_ring().
-doc(~" Move focus to the previous slot (wraps around).").
focus_prev(Ring) ->
    N = erlang:length(erlang:element(2, Ring)),
    case N of
        0 ->
            Ring;

        _ ->
            {focus_ring, erlang:element(2, Ring), begin
                _pipe = (erlang:element(3, Ring) + N) - 1,
                _pipe@1 = gleam@int:modulo(_pipe, N),
                unwrap_zero(_pipe@1)
            end}
    end.

-file("src/etui/focus.gleam", 132).
-spec index_of(list(binary()), binary(), integer()) -> {ok, integer()} | {error, nil}.
index_of(Lst, Target, Acc) ->
    case Lst of
        [] ->
            {error, nil};

        [H | Rest] ->
            case H =:= Target of
                true ->
                    {ok, Acc};

                false ->
                    index_of(Rest, Target, Acc + 1)
            end
    end.

-file("src/etui/focus.gleam", 97).
-spec focus_id(focus_ring(), binary()) -> focus_ring().
-doc(~" Move focus to the slot with the given `id`. No-op if `id` not found.").
focus_id(Ring, Id) ->
    case index_of(erlang:element(2, Ring), Id, 0) of
        {ok, I} ->
            {focus_ring, erlang:element(2, Ring), I};

        {error, _} ->
            Ring
    end.

-file("src/etui/focus.gleam", 105).
-spec focus_index(focus_ring(), integer()) -> focus_ring().
-doc(~" Move focus to the slot at the given index (clamped to valid range).").
focus_index(Ring, Idx) ->
    N = erlang:length(erlang:element(2, Ring)),
    case N of
        0 ->
            Ring;

        _ ->
            {focus_ring, erlang:element(2, Ring), gleam@int:clamp(Idx, 0, N - 1)}
    end.

