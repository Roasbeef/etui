-module(etui@widgets@gauge).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([gauge_new/1, with_label/2, with_chars/3, with_colors/3, with_filled_modifier/2, with_style/2, render/3]).
-export_type([gauge/0]).

-type gauge() :: {gauge, integer(), binary(), binary(), binary(), etui@style:color(), etui@style:color(), etui@style:modifier(), etui@style:modifier()}.

-file("src/etui/widgets/gauge.gleam", 39).
-spec gauge_new(integer()) -> gauge().
-doc(~" New gauge at the given percent (clamped to 0–100). Default chars: `█`/`░`.").
gauge_new(Percent) ->
    {gauge, gleam@int:clamp(Percent, 0, 100), ~"", ~"█", ~"░", default, default, etui@style:none(), etui@style:none()}.

-file("src/etui/widgets/gauge.gleam", 53).
-spec with_label(gauge(), binary()) -> gauge().
-doc(~" Set a label overlaid centered on the bar.").
with_label(G, Label) ->
    {gauge, erlang:element(2, G), Label, erlang:element(4, G), erlang:element(5, G), erlang:element(6, G), erlang:element(7, G), erlang:element(8, G), erlang:element(9, G)}.

-file("src/etui/widgets/gauge.gleam", 58).
-spec with_chars(gauge(), binary(), binary()) -> gauge().
-doc(~" Set filled and empty characters (single-cell graphemes only).").
with_chars(G, Filled, Empty) ->
    {gauge, erlang:element(2, G), erlang:element(3, G), Filled, Empty, erlang:element(6, G), erlang:element(7, G), erlang:element(8, G), erlang:element(9, G)}.

-file("src/etui/widgets/gauge.gleam", 63).
-spec with_colors(gauge(), etui@style:color(), etui@style:color()) -> gauge().
-doc(~" Set fg/bg colors for both filled and empty sections.").
with_colors(G, Fg, Bg) ->
    {gauge, erlang:element(2, G), erlang:element(3, G), erlang:element(4, G), erlang:element(5, G), Fg, Bg, erlang:element(8, G), erlang:element(9, G)}.

-file("src/etui/widgets/gauge.gleam", 68).
-spec with_filled_modifier(gauge(), etui@style:modifier()) -> gauge().
-doc(~" Apply a modifier (bold, etc.) to the filled section only.").
with_filled_modifier(G, Modifier) ->
    {gauge, erlang:element(2, G), erlang:element(3, G), erlang:element(4, G), erlang:element(5, G), erlang:element(6, G), erlang:element(7, G), Modifier, erlang:element(9, G)}.

-file("src/etui/widgets/gauge.gleam", 73).
-spec with_style(gauge(), etui@style:style()) -> gauge().
-doc(~" Apply a style (fg/bg) via a `Style` value.").
with_style(G, S) ->
    {gauge, erlang:element(2, G), erlang:element(3, G), erlang:element(4, G), erlang:element(5, G), erlang:element(2, S), erlang:element(3, S), erlang:element(8, G), erlang:element(9, G)}.

-file("src/etui/widgets/gauge.gleam", 149).
-spec do_fill(etui@buffer:buffer(), etui@geometry:position(), integer(), integer(), binary(), etui@style:color(), etui@style:color(), etui@style:modifier()) -> etui@buffer:buffer().
do_fill(Buf, Start, Count, I, Char, Fg, Bg, Modifier) ->
    case I >= Count of
        true ->
            Buf;

        false ->
            Pos = {position, erlang:element(2, Start) + I, erlang:element(3, Start)},
            Buf_new = etui@buffer:set_cell(Buf, Pos, {cell, {content, Char, 1}, etui@style:new(Fg, Bg, Modifier), ~""}),
            do_fill(Buf_new, Start, Count, I + 1, Char, Fg, Bg, Modifier)
    end.

-file("src/etui/widgets/gauge.gleam", 137).
-spec fill_cells(etui@buffer:buffer(), etui@geometry:position(), integer(), binary(), etui@style:color(), etui@style:color(), etui@style:modifier()) -> etui@buffer:buffer().
fill_cells(Buf, Pos, Count, Char, Fg, Bg, Modifier) ->
    do_fill(Buf, Pos, Count, 0, Char, Fg, Bg, Modifier).

-file("src/etui/widgets/gauge.gleam", 92).
-spec render_bar(etui@buffer:buffer(), etui@geometry:rect(), gauge()) -> etui@buffer:buffer().
render_bar(Buf, Area, G) ->
    Width = erlang:element(2, erlang:element(3, Area)),
    Filled = gleam@int:clamp((Width * erlang:element(2, G)) div 100, 0, Width),
    Empty = Width - Filled,
    Buf1 = fill_cells(Buf, erlang:element(2, Area), Filled, erlang:element(4, G), erlang:element(6, G), erlang:element(7, G), erlang:element(8, G)),
    Buf2 = fill_cells(Buf1, {position, erlang:element(2, erlang:element(2, Area)) + Filled, erlang:element(3, erlang:element(2, Area))}, Empty, erlang:element(5, G), erlang:element(6, G), erlang:element(7, G), erlang:element(9, G)),
    case erlang:element(3, G) of
        ~"" ->
            Buf2;

        Label ->
            Label_width = etui@text:cell_width(Label),
            Label_x = erlang:element(2, erlang:element(2, Area)) + gleam@int:max(0, (Width - Label_width) div 2),
            etui@buffer:set_string(Buf2, {position, Label_x, erlang:element(3, erlang:element(2, Area))}, etui@text:truncate(Label, Width, ~""), etui@style:new(erlang:element(6, G), erlang:element(7, G), etui@style:none()))
    end.

-file("src/etui/widgets/gauge.gleam", 81).
-spec render(etui@buffer:buffer(), etui@geometry:rect(), gauge()) -> etui@buffer:buffer().
-doc(~" Render the gauge bar into the first row of `area`.").
render(Buf, Area, G) ->
    case (erlang:element(2, erlang:element(3, Area)) =< 0) orelse (erlang:element(3, erlang:element(3, Area)) =< 0) of
        true ->
            Buf;

        false ->
            render_bar(Buf, Area, G)
    end.

