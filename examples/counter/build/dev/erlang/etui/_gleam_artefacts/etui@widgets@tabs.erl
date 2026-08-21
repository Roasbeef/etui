-module(etui@widgets@tabs).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([tabs_new/1, with_active/2, with_active_style/2, with_divider/2, with_padding/2, with_colors/3, next_tab/1, prev_tab/1, render/3]).
-export_type([tabs/0]).

-type tabs() :: {tabs, list(binary()), integer(), etui@style:color(), etui@style:color(), etui@style:style(), binary(), integer()}.

-file("src/etui/widgets/tabs.gleam", 31).
-spec tabs_new(list(binary())) -> tabs().
tabs_new(Labels) ->
    {tabs, Labels, 0, default, default, {style, default, default, etui@style:add(etui@style:bold(), etui@style:reverse()), etui@style:none(), default}, ~"│", 1}.

-file("src/etui/widgets/tabs.gleam", 49).
-spec with_active(tabs(), integer()) -> tabs().
with_active(T, Idx) ->
    {tabs, erlang:element(2, T), gleam@int:max(0, Idx), erlang:element(4, T), erlang:element(5, T), erlang:element(6, T), erlang:element(7, T), erlang:element(8, T)}.

-file("src/etui/widgets/tabs.gleam", 53).
-spec with_active_style(tabs(), etui@style:style()) -> tabs().
with_active_style(T, S) ->
    {tabs, erlang:element(2, T), erlang:element(3, T), erlang:element(4, T), erlang:element(5, T), S, erlang:element(7, T), erlang:element(8, T)}.

-file("src/etui/widgets/tabs.gleam", 57).
-spec with_divider(tabs(), binary()) -> tabs().
with_divider(T, Div) ->
    {tabs, erlang:element(2, T), erlang:element(3, T), erlang:element(4, T), erlang:element(5, T), erlang:element(6, T), Div, erlang:element(8, T)}.

-file("src/etui/widgets/tabs.gleam", 61).
-spec with_padding(tabs(), integer()) -> tabs().
with_padding(T, P) ->
    {tabs, erlang:element(2, T), erlang:element(3, T), erlang:element(4, T), erlang:element(5, T), erlang:element(6, T), erlang:element(7, T), gleam@int:max(0, P)}.

-file("src/etui/widgets/tabs.gleam", 65).
-spec with_colors(tabs(), etui@style:color(), etui@style:color()) -> tabs().
with_colors(T, Fg, Bg) ->
    {tabs, erlang:element(2, T), erlang:element(3, T), Fg, Bg, erlang:element(6, T), erlang:element(7, T), erlang:element(8, T)}.

-file("src/etui/widgets/tabs.gleam", 71).
-spec next_tab(tabs()) -> tabs().
next_tab(T) ->
    N = erlang:length(erlang:element(2, T)),
    {tabs, erlang:element(2, T), case gleam@int:max(1, N) of
        0 ->
            0;

        _value ->
            (erlang:element(3, T) + 1) rem _value
    end, erlang:element(4, T), erlang:element(5, T), erlang:element(6, T), erlang:element(7, T), erlang:element(8, T)}.

-file("src/etui/widgets/tabs.gleam", 76).
-spec prev_tab(tabs()) -> tabs().
prev_tab(T) ->
    N = gleam@int:max(1, erlang:length(erlang:element(2, T))),
    {tabs, erlang:element(2, T), case N of
        0 ->
            0;

        _value ->
            ((erlang:element(3, T) - 1) + N) rem _value
    end, erlang:element(4, T), erlang:element(5, T), erlang:element(6, T), erlang:element(7, T), erlang:element(8, T)}.

-file("src/etui/widgets/tabs.gleam", 164).
-spec string_length(binary()) -> integer().
string_length(S) ->
    etui@text:cell_width(S).

-file("src/etui/widgets/tabs.gleam", 157).
-spec make_spaces(integer()) -> binary().
make_spaces(N) ->
    case N =< 0 of
        true ->
            ~"";

        false ->
            <<" "/utf8, (make_spaces(N - 1))/binary>>
    end.

-file("src/etui/widgets/tabs.gleam", 96).
-spec render_tabs(etui@buffer:buffer(), etui@geometry:rect(), list(binary()), integer(), integer(), tabs()) -> etui@buffer:buffer().
render_tabs(Buf, Area, Labels, Idx, X, T) ->
    case Labels of
        [] ->
            Buf;

        [Label | Rest] ->
            Pad = make_spaces(erlang:element(8, T)),
            Content = <<<<Pad/binary, Label/binary>>/binary, Pad/binary>>,
            Is_active = Idx =:= erlang:element(3, T),
            {Fg, Bg, Modifier} = case Is_active of
                true ->
                    {erlang:element(2, erlang:element(6, T)), erlang:element(3, erlang:element(6, T)), erlang:element(4, erlang:element(6, T))};

                false ->
                    {erlang:element(4, T), erlang:element(5, T), etui@style:none()}
            end,
            Avail = (erlang:element(2, erlang:element(2, Area)) + erlang:element(2, erlang:element(3, Area))) - X,
            Shown = etui@text:truncate(Content, Avail, ~""),
            Buf2 = etui@buffer:set_string(Buf, {position, X, erlang:element(3, erlang:element(2, Area))}, Shown, etui@style:new(Fg, Bg, Modifier)),
            Next_x = X + string_length(Content),
            case Rest of
                [] ->
                    Buf2;

                _ ->
                    Div_avail = (erlang:element(2, erlang:element(2, Area)) + erlang:element(2, erlang:element(3, Area))) - Next_x,
                    case Div_avail =< 0 of
                        true ->
                            Buf2;

                        false ->
                            Buf3 = etui@buffer:set_string(Buf2, {position, Next_x, erlang:element(3, erlang:element(2, Area))}, erlang:element(7, T), etui@style:new(erlang:element(4, T), erlang:element(5, T), etui@style:none())),
                            render_tabs(Buf3, Area, Rest, Idx + 1, Next_x + string_length(erlang:element(7, T)), T)
                    end
            end
    end.

-file("src/etui/widgets/tabs.gleam", 85).
-spec render(etui@buffer:buffer(), etui@geometry:rect(), tabs()) -> etui@buffer:buffer().
-doc(~" Render the tab bar into the first row of `area`.").
render(Buf, Area, T) ->
    case (erlang:element(3, erlang:element(3, Area)) =< 0) orelse (erlang:element(2, erlang:element(3, Area)) =< 0) of
        true ->
            Buf;

        false ->
            render_tabs(Buf, Area, erlang:element(2, T), 0, erlang:element(2, erlang:element(2, Area)), T)
    end.

