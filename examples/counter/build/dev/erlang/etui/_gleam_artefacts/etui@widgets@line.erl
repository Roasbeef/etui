-module(etui@widgets@line).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([line_new/0, with_color/2, render_horizontal/3, render_vertical/3]).
-export_type([line_style/0, line/0]).

-type line_style() :: solid.

-type line() :: {line, line_style(), etui@style:color()}.

-file("src/etui/widgets/line.gleam", 23).
-spec line_new() -> line().
-doc(~" New solid line with default terminal color.").
line_new() ->
    {line, solid, default}.

-file("src/etui/widgets/line.gleam", 28).
-spec with_color(line(), etui@style:color()) -> line().
-doc(~" Set the line color.").
with_color(L, Color) ->
    {line, erlang:element(2, L), Color}.

-file("src/etui/widgets/line.gleam", 47).
-spec render_horizontal_line(etui@buffer:buffer(), etui@geometry:rect(), line(), integer(), binary()) -> etui@buffer:buffer().
render_horizontal_line(Buf, Area, L, X, Char) ->
    case X >= erlang:element(2, erlang:element(3, Area)) of
        true ->
            Buf;

        false ->
            Pos = {position, erlang:element(2, erlang:element(2, Area)) + X, erlang:element(3, erlang:element(2, Area))},
            Buf_new = etui@buffer:set_string(Buf, Pos, Char, etui@style:new(erlang:element(3, L), default, etui@style:none())),
            render_horizontal_line(Buf_new, Area, L, X + 1, Char)
    end.

-file("src/etui/widgets/line.gleam", 36).
-spec render_horizontal(etui@buffer:buffer(), etui@geometry:rect(), line()) -> etui@buffer:buffer().
-doc(~" Render horizontal line.").
render_horizontal(Buf, Area, L) ->
    case erlang:element(2, erlang:element(3, Area)) =< 0 of
        true ->
            Buf;

        false ->
            render_horizontal_line(Buf, Area, L, 0, ~"─")
    end.

-file("src/etui/widgets/line.gleam", 85).
-spec render_vertical_line(etui@buffer:buffer(), etui@geometry:rect(), line(), integer(), binary()) -> etui@buffer:buffer().
render_vertical_line(Buf, Area, L, Y, Char) ->
    case Y >= erlang:element(3, erlang:element(3, Area)) of
        true ->
            Buf;

        false ->
            Pos = {position, erlang:element(2, erlang:element(2, Area)), erlang:element(3, erlang:element(2, Area)) + Y},
            Buf_new = etui@buffer:set_string(Buf, Pos, Char, etui@style:new(erlang:element(3, L), default, etui@style:none())),
            render_vertical_line(Buf_new, Area, L, Y + 1, Char)
    end.

-file("src/etui/widgets/line.gleam", 71).
-spec render_vertical(etui@buffer:buffer(), etui@geometry:rect(), line()) -> etui@buffer:buffer().
-doc(~" Render vertical line.").
render_vertical(Buf, Area, L) ->
    case erlang:element(3, erlang:element(3, Area)) =< 0 of
        true ->
            Buf;

        false ->
            Char = ~"│",
            render_vertical_line(Buf, Area, L, 0, Char)
    end.

