-module(etui@widgets@canvas).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([canvas_new/1, series_new/1, with_series_fill/2, with_max/2, with_bg/2, with_period/2, render/4]).
-export_type([series_fill/0, series/0, canvas/0]).

-type series_fill() :: {series_solid, etui@style:color()} | {series_gradient, list(etui@style:color())} | series_rainbow | series_animated_rainbow.

-type series() :: {series, list(integer()), series_fill()}.

-type canvas() :: {canvas, list(series()), integer(), etui@style:color(), integer()}.

-file("src/etui/widgets/canvas.gleam", 45).
-spec canvas_new(list(series())) -> canvas().
canvas_new(Series) ->
    {canvas, Series, 0, default, 60}.

-file("src/etui/widgets/canvas.gleam", 49).
-spec series_new(list(integer())) -> series().
series_new(Data) ->
    {series, Data, series_rainbow}.

-file("src/etui/widgets/canvas.gleam", 53).
-spec with_series_fill(series(), series_fill()) -> series().
with_series_fill(S, Fill) ->
    {series, erlang:element(2, S), Fill}.

-file("src/etui/widgets/canvas.gleam", 57).
-spec with_max(canvas(), integer()) -> canvas().
with_max(C, Max) ->
    {canvas, erlang:element(2, C), gleam@int:max(1, Max), erlang:element(4, C), erlang:element(5, C)}.

-file("src/etui/widgets/canvas.gleam", 61).
-spec with_bg(canvas(), etui@style:color()) -> canvas().
with_bg(C, Bg) ->
    {canvas, erlang:element(2, C), erlang:element(3, C), Bg, erlang:element(5, C)}.

-file("src/etui/widgets/canvas.gleam", 65).
-spec with_period(canvas(), integer()) -> canvas().
with_period(C, Period) ->
    {canvas, erlang:element(2, C), erlang:element(3, C), erlang:element(4, C), gleam@int:max(1, Period)}.

-file("src/etui/widgets/canvas.gleam", 219).
-spec series_color(series_fill(), integer(), integer(), integer(), integer()) -> etui@style:color().
series_color(Fill, Px, Pw, Frame, Period) ->
    P = gleam@int:max(1, Period),
    W = gleam@int:max(1, Pw),
    case Fill of
        {series_solid, C} ->
            C;

        {series_gradient, Stops} ->
            etui@color:gradient(Stops, Px, W - 1);

        series_rainbow ->
            etui@color:hue_to_rgb(case W of
                0 ->
                    0;

                _value ->
                    (Px * 360) div _value
            end);

        series_animated_rainbow ->
            etui@color:hue_to_rgb((case W of
                0 ->
                    0;

                _value@1 ->
                    (Px * 360) div _value@1
            end + case P of
                0 ->
                    0;

                _value@2 ->
                    (Frame * 360) div _value@2
            end) rem 360)
    end.

-file("src/etui/widgets/canvas.gleam", 186).
-spec bresenham_loop(integer(), integer(), integer(), integer(), integer(), integer(), integer(), integer(), integer(), list({integer(), integer()})) -> list({integer(), integer()}).
bresenham_loop(X0, Y0, X1, Y1, Sx, Sy, Dx, Dy, Err, Acc) ->
    Acc@1 = [{X0, Y0} | Acc],
    case (X0 =:= X1) andalso (Y0 =:= Y1) of
        true ->
            Acc@1;

        false ->
            E2 = 2 * Err,
            {Err@1, X0@1} = case E2 >= Dy of
                true ->
                    {Err + Dy, X0 + Sx};

                false ->
                    {Err, X0}
            end,
            {Err@2, Y0@1} = case E2 =< Dx of
                true ->
                    {Err@1 + Dx, Y0 + Sy};

                false ->
                    {Err@1, Y0}
            end,
            bresenham_loop(X0@1, Y0@1, X1, Y1, Sx, Sy, Dx, Dy, Err@2, Acc@1)
    end.

-file("src/etui/widgets/canvas.gleam", 172).
-spec bresenham(integer(), integer(), integer(), integer()) -> list({integer(), integer()}).
bresenham(X0, Y0, X1, Y1) ->
    Dx = gleam@int:absolute_value(X1 - X0),
    Dy = 0 - gleam@int:absolute_value(Y1 - Y0),
    Sx = case X0 < X1 of
        true ->
            1;

        false ->
            -1
    end,
    Sy = case Y0 < Y1 of
        true ->
            1;

        false ->
            -1
    end,
    bresenham_loop(X0, Y0, X1, Y1, Sx, Sy, Dx, Dy, Dx + Dy, []).

-file("src/etui/widgets/canvas.gleam", 143).
-spec draw_segments(gleam@dict:dict({integer(), integer()}, {integer(), etui@style:color()}), series(), list({integer(), integer()}), integer(), integer(), integer()) -> gleam@dict:dict({integer(), integer()}, {integer(), etui@style:color()}).
draw_segments(Pixels, Ser, Coords, Pw, Frame, Period) ->
    case Coords of
        [] ->
            Pixels;

        [_] ->
            Pixels;

        [P0, P1 | Rest] ->
            {X0, Y0} = P0,
            {X1, Y1} = P1,
            Pts = bresenham(X0, Y0, X1, Y1),
            Pixels@1 = gleam@list:fold(Pts, Pixels, fun(Px_dict, Pt) ->
                {Px, Py} = Pt,
                Fg = series_color(erlang:element(3, Ser), Px, Pw, Frame, Period),
                etui@braille:put(Px_dict, Px, Py, Fg)
            end),
            draw_segments(Pixels@1, Ser, [P1 | Rest], Pw, Frame, Period)
    end.

-file("src/etui/widgets/canvas.gleam", 122).
-spec data_to_coords(list(integer()), integer(), integer(), integer(), integer()) -> list({integer(), integer()}).
data_to_coords(Data, N, Pw, Ph, Max) ->
    Range = gleam@int:max(1, Max),
    Max_px = gleam@int:max(0, Pw - 1),
    Max_py = gleam@int:max(0, Ph - 1),
    gleam@list:index_map(Data, fun(Val, I) ->
        Px = case N =< 1 of
            true ->
                0;

            false ->
                case N - 1 of
                    0 ->
                        0;

                    _value ->
                        (I * Max_px) div _value
                end
        end,
        Clamped = gleam@int:clamp(Val, 0, Range),
        Py = Max_py - case Range of
            0 ->
                0;

            _value@1 ->
                (Clamped * Max_py) div _value@1
        end,
        {Px, Py}
    end).

-file("src/etui/widgets/canvas.gleam", 103).
-spec draw_series(gleam@dict:dict({integer(), integer()}, {integer(), etui@style:color()}), series(), integer(), integer(), integer(), integer(), integer()) -> gleam@dict:dict({integer(), integer()}, {integer(), etui@style:color()}).
draw_series(Pixels, Ser, Pw, Ph, Max, Frame, Period) ->
    N = erlang:length(erlang:element(2, Ser)),
    case N of
        0 ->
            Pixels;

        _ ->
            Coords = data_to_coords(erlang:element(2, Ser), N, Pw, Ph, Max),
            draw_segments(Pixels, Ser, Coords, Pw, Frame, Period)
    end.

-file("src/etui/widgets/canvas.gleam", 73).
-spec render(etui@buffer:buffer(), etui@geometry:rect(), canvas(), integer()) -> etui@buffer:buffer().
-doc(~" Render canvas into `area`. `frame` drives animated fills.").
render(Buf, Area, C, Frame) ->
    case (erlang:element(2, erlang:element(3, Area)) =< 0) orelse (erlang:element(3, erlang:element(3, Area)) =< 0) of
        true ->
            Buf;

        false ->
            Pw = erlang:element(2, erlang:element(3, Area)) * 2,
            Ph = erlang:element(3, erlang:element(3, Area)) * 4,
            Max = case erlang:element(3, C) of
                0 ->
                    gleam@list:fold(erlang:element(2, C), 1, fun(Acc, Ser) ->
                        gleam@list:fold(erlang:element(2, Ser), Acc, fun gleam@int:max/2)
                    end);

                M ->
                    M
            end,
            Pixels = gleam@list:index_fold(erlang:element(2, C), etui@braille:new(), fun(Px_dict, Ser, _) ->
                draw_series(Px_dict, Ser, Pw, Ph, Max, Frame, erlang:element(5, C))
            end),
            etui@braille:flush(Buf, Area, Pixels, erlang:element(4, C))
    end.

