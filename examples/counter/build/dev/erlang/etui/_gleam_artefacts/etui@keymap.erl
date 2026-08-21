-module(etui@keymap).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([keymap_new/0, bind/4, unbind/2, merge/2, lookup/2, help_lines/1, all_bindings/1, render_help/4, filter/2]).
-export_type([binding/1, keymap/1]).

-type binding(FMQ) :: {binding, binary(), FMQ, binary()}.

-type keymap(FMR) :: {keymap, list(binding(FMR))}.

-file("src/etui/keymap.gleam", 52).
-spec keymap_new() -> keymap(any()).
-doc(~" Empty keymap.").
keymap_new() ->
    {keymap, []}.

-file("src/etui/keymap.gleam", 58).
-spec bind(keymap(FMU), binary(), FMU, binary()) -> keymap(FMU).
-doc(~" Add a binding to the end of the keymap.
 The first matching binding wins on `lookup`.").
bind(Km, Key, Action, Description) ->
    {keymap, lists:append(erlang:element(2, Km), [{binding, Key, Action, Description}])}.

-file("src/etui/keymap.gleam", 70).
-spec unbind(keymap(FMX), binary()) -> keymap(FMX).
-doc(~" Remove all bindings for a given key.").
unbind(Km, Key) ->
    {keymap, gleam@list:filter(erlang:element(2, Km), fun(B) ->
        erlang:element(2, B) /= Key
    end)}.

-file("src/etui/keymap.gleam", 75).
-spec merge(keymap(FNA), keymap(FNA)) -> keymap(FNA).
-doc(~" Merge `other` into `km`. Bindings from `other` are appended.").
merge(Km, Other) ->
    {keymap, lists:append(erlang:element(2, Km), erlang:element(2, Other))}.

-file("src/etui/keymap.gleam", 83).
-spec lookup(keymap(FNE), binary()) -> {ok, FNE} | {error, nil}.
-doc(~" Find the action bound to `key`. Returns `Error(Nil)` if not found.").
lookup(Km, Key) ->
    case gleam@list:find(erlang:element(2, Km), fun(B) ->
        erlang:element(2, B) =:= Key
    end) of
        {ok, B} ->
            {ok, erlang:element(3, B)};

        {error, _} ->
            {error, nil}
    end.

-file("src/etui/keymap.gleam", 91).
-spec help_lines(keymap(any())) -> list({binary(), binary()}).
-doc(~" All bindings as `#(key, description)` pairs, in registration order.").
help_lines(Km) ->
    gleam@list:map(erlang:element(2, Km), fun(B) ->
        {erlang:element(2, B), erlang:element(4, B)}
    end).

-file("src/etui/keymap.gleam", 96).
-spec all_bindings(keymap(FNL)) -> list({binary(), FNL}).
-doc(~" All bindings as `#(key, action)` pairs.").
all_bindings(Km) ->
    gleam@list:map(erlang:element(2, Km), fun(B) ->
        {erlang:element(2, B), erlang:element(3, B)}
    end).

-file("src/etui/keymap.gleam", 129).
-spec render_help_rows(etui@buffer:buffer(), etui@geometry:rect(), list({binary(), binary()}), integer(), etui@style:style(), integer()) -> etui@buffer:buffer().
render_help_rows(Buf, Area, Lines, Key_w, St, Row) ->
    case (Row >= erlang:element(3, erlang:element(3, Area))) orelse gleam@list:is_empty(Lines) of
        true ->
            Buf;

        false ->
            case Lines of
                [] ->
                    Buf;

                [{Key, Desc} | Rest] ->
                    Padded_key = etui@text:pad_right(Key, Key_w),
                    Row_text = <<<<Padded_key/binary, "  "/utf8>>/binary, (etui@text:truncate(Desc, (erlang:element(2, erlang:element(3, Area)) - Key_w) - 2, ~""))/binary>>,
                    Trimmed = etui@text:truncate(Row_text, erlang:element(2, erlang:element(3, Area)), ~""),
                    Padded = etui@text:pad_right(Trimmed, erlang:element(2, erlang:element(3, Area))),
                    Buf2 = etui@buffer:set_string(Buf, {position, erlang:element(2, erlang:element(2, Area)), erlang:element(3, erlang:element(2, Area)) + Row}, Padded, St),
                    render_help_rows(Buf2, Area, Rest, Key_w, St, Row + 1)
            end
    end.

-file("src/etui/keymap.gleam", 107).
-spec render_help(etui@buffer:buffer(), etui@geometry:rect(), keymap(any()), etui@style:style()) -> etui@buffer:buffer().
-doc(~" Render a help table into `area`.
 Each row shows `  key_col  description`. `key_col_width` is the
 minimum column width for keys (auto-computed if 0).
 Returns the buffer with the help overlay drawn.").
render_help(Buf, Area, Km, St) ->
    Lines = help_lines(Km),
    Key_w = case gleam@list:fold(Lines, 0, fun(Acc, Pair) ->
        {K, _} = Pair,
        case etui@text:cell_width(K) > Acc of
            true ->
                etui@text:cell_width(K);

            false ->
                Acc
        end
    end) of
        0 ->
            6;

        N ->
            N
    end,
    render_help_rows(Buf, Area, Lines, Key_w, St, 0).

-file("src/etui/keymap.gleam", 168).
-spec filter(keymap(FNR), binary()) -> keymap(FNR).
-doc(~" Keep only bindings whose description contains `query` (case-insensitive).
 Useful for a live-filter command palette.").
filter(Km, Query) ->
    case Query of
        ~"" ->
            Km;

        Q ->
            Lower_q = string:lowercase(Q),
            {keymap, gleam@list:filter(erlang:element(2, Km), fun(B) ->
                gleam_stdlib:contains_string(string:lowercase(erlang:element(4, B)), Lower_q) orelse gleam_stdlib:contains_string(string:lowercase(erlang:element(2, B)), Lower_q)
            end)}
    end.

