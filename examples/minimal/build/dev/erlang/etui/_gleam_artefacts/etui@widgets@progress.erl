-module(etui@widgets@progress).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([progress_new/1, progress_indeterminate/0, with_label/2, with_chars/3, with_segment_width/2, with_colors/3, with_style/2, with_filled_modifier/2, with_empty_modifier/2, render/4]).
-export_type([progress_mode/0, progress_bar/0]).

-type progress_mode() :: {determinate, integer()} | indeterminate.

-type progress_bar() :: {progress_bar, progress_mode(), binary(), binary(), binary(), integer(), etui@style:color(), etui@style:color(), etui@style:modifier(), etui@style:modifier()}.

-file("src/etui/widgets/progress.gleam", 36).
-spec progress_new(integer()) -> progress_bar().
progress_new(Percent) ->
    {progress_bar, {determinate, gleam@int:clamp(Percent, 0, 100)}, ~"", ~"█", ~"░", 25, default, default, etui@style:none(), etui@style:none()}.

-file("src/etui/widgets/progress.gleam", 50).
-spec progress_indeterminate() -> progress_bar().
progress_indeterminate() ->
    {progress_bar, indeterminate, ~"", ~"█", ~"░", 25, default, default, etui@style:none(), etui@style:none()}.

-file("src/etui/widgets/progress.gleam", 64).
-spec with_label(progress_bar(), binary()) -> progress_bar().
with_label(P, Label) ->
    {progress_bar, erlang:element(2, P), Label, erlang:element(4, P), erlang:element(5, P), erlang:element(6, P), erlang:element(7, P), erlang:element(8, P), erlang:element(9, P), erlang:element(10, P)}.

-file("src/etui/widgets/progress.gleam", 68).
-spec with_chars(progress_bar(), binary(), binary()) -> progress_bar().
with_chars(P, Filled, Empty) ->
    {progress_bar, erlang:element(2, P), erlang:element(3, P), Filled, Empty, erlang:element(6, P), erlang:element(7, P), erlang:element(8, P), erlang:element(9, P), erlang:element(10, P)}.

-file("src/etui/widgets/progress.gleam", 77).
-spec with_segment_width(progress_bar(), integer()) -> progress_bar().
-doc(~" Indeterminate segment size as a percentage of bar width (1–100).").
with_segment_width(P, Pct) ->
    {progress_bar, erlang:element(2, P), erlang:element(3, P), erlang:element(4, P), erlang:element(5, P), gleam@int:clamp(Pct, 1, 100), erlang:element(7, P), erlang:element(8, P), erlang:element(9, P), erlang:element(10, P)}.

-file("src/etui/widgets/progress.gleam", 81).
-spec with_colors(progress_bar(), etui@style:color(), etui@style:color()) -> progress_bar().
with_colors(P, Fg, Bg) ->
    {progress_bar, erlang:element(2, P), erlang:element(3, P), erlang:element(4, P), erlang:element(5, P), erlang:element(6, P), Fg, Bg, erlang:element(9, P), erlang:element(10, P)}.

-file("src/etui/widgets/progress.gleam", 89).
-spec with_style(progress_bar(), etui@style:style()) -> progress_bar().
with_style(P, S) ->
    {progress_bar, erlang:element(2, P), erlang:element(3, P), erlang:element(4, P), erlang:element(5, P), erlang:element(6, P), erlang:element(2, S), erlang:element(3, S), erlang:element(9, P), erlang:element(10, P)}.

-file("src/etui/widgets/progress.gleam", 93).
-spec with_filled_modifier(progress_bar(), etui@style:modifier()) -> progress_bar().
with_filled_modifier(P, M) ->
    {progress_bar, erlang:element(2, P), erlang:element(3, P), erlang:element(4, P), erlang:element(5, P), erlang:element(6, P), erlang:element(7, P), erlang:element(8, P), M, erlang:element(10, P)}.

-file("src/etui/widgets/progress.gleam", 97).
-spec with_empty_modifier(progress_bar(), etui@style:modifier()) -> progress_bar().
with_empty_modifier(P, M) ->
    {progress_bar, erlang:element(2, P), erlang:element(3, P), erlang:element(4, P), erlang:element(5, P), erlang:element(6, P), erlang:element(7, P), erlang:element(8, P), erlang:element(9, P), M}.

-file("src/etui/widgets/progress.gleam", 217).
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

-file("src/etui/widgets/progress.gleam", 205).
-spec fill_cells(etui@buffer:buffer(), etui@geometry:position(), integer(), binary(), etui@style:color(), etui@style:color(), etui@style:modifier()) -> etui@buffer:buffer().
fill_cells(Buf, Pos, Count, Char, Fg, Bg, Modifier) ->
    do_fill(Buf, Pos, Count, 0, Char, Fg, Bg, Modifier).

-file("src/etui/widgets/progress.gleam", 168).
-spec render_indeterminate(etui@buffer:buffer(), etui@geometry:rect(), progress_bar(), integer()) -> etui@buffer:buffer().
render_indeterminate(Buf, Area, P, Frame) ->
    Width = erlang:element(2, erlang:element(3, Area)),
    Seg = gleam@int:max(1, (Width * erlang:element(6, P)) div 100),
    Max_start = gleam@int:max(0, Width - Seg),
    Period = gleam@int:max(1, (Max_start + Seg) * 2),
    Seg_start = etui@anim:oscillate(0, Max_start, Frame, Period),
    Buf1 = fill_cells(Buf, erlang:element(2, Area), Width, erlang:element(5, P), erlang:element(7, P), erlang:element(8, P), erlang:element(10, P)),
    fill_cells(Buf1, {position, erlang:element(2, erlang:element(2, Area)) + Seg_start, erlang:element(3, erlang:element(2, Area))}, Seg, erlang:element(4, P), erlang:element(7, P), erlang:element(8, P), erlang:element(9, P)).

-file("src/etui/widgets/progress.gleam", 124).
-spec render_determinate(etui@buffer:buffer(), etui@geometry:rect(), progress_bar(), integer()) -> etui@buffer:buffer().
render_determinate(Buf, Area, P, Pct) ->
    Width = erlang:element(2, erlang:element(3, Area)),
    Filled = gleam@int:clamp((Width * Pct) div 100, 0, Width),
    Empty = Width - Filled,
    Buf1 = fill_cells(Buf, erlang:element(2, Area), Filled, erlang:element(4, P), erlang:element(7, P), erlang:element(8, P), erlang:element(9, P)),
    Buf2 = fill_cells(Buf1, {position, erlang:element(2, erlang:element(2, Area)) + Filled, erlang:element(3, erlang:element(2, Area))}, Empty, erlang:element(5, P), erlang:element(7, P), erlang:element(8, P), erlang:element(10, P)),
    case erlang:element(3, P) of
        ~"" ->
            Buf2;

        Label ->
            Lw = etui@text:cell_width(Label),
            Lx = erlang:element(2, erlang:element(2, Area)) + gleam@int:max(0, (Width - Lw) div 2),
            etui@buffer:set_string(Buf2, {position, Lx, erlang:element(3, erlang:element(2, Area))}, etui@text:truncate(Label, Width, ~""), etui@style:new(erlang:element(7, P), erlang:element(8, P), etui@style:none()))
    end.

-file("src/etui/widgets/progress.gleam", 108).
-spec render(etui@buffer:buffer(), etui@geometry:rect(), progress_bar(), integer()) -> etui@buffer:buffer().
render(Buf, Area, P, Frame) ->
    case (erlang:element(2, erlang:element(3, Area)) =< 0) orelse (erlang:element(3, erlang:element(3, Area)) =< 0) of
        true ->
            Buf;

        false ->
            case erlang:element(2, P) of
                {determinate, Pct} ->
                    render_determinate(Buf, Area, P, Pct);

                indeterminate ->
                    render_indeterminate(Buf, Area, P, Frame)
            end
    end.

