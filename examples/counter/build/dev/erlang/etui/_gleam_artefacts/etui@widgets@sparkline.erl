-module(etui@widgets@sparkline).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([sparkline_new/1, with_fill/2, with_max/2, with_bg/2, with_period/2, with_modifier/2, with_style/2, render/4]).
-export_type([spark_fill/0, sparkline/0]).

-type spark_fill() :: {spark_gradient, list(etui@style:color())} | {spark_animated, list(etui@style:color())} | spark_rainbow | spark_animated_rainbow | {spark_solid, etui@style:color()}.

-type sparkline() :: {sparkline, list(integer()), integer(), spark_fill(), etui@style:color(), etui@style:modifier(), integer()}.

-file("src/etui/widgets/sparkline.gleam", 43).
-spec sparkline_new(list(integer())) -> sparkline().
sparkline_new(Data) ->
    {sparkline, Data, 0, {spark_gradient, [{rgb, 0, 180, 255}, {rgb, 0, 255, 180}]}, default, etui@style:none(), 60}.

-file("src/etui/widgets/sparkline.gleam", 54).
-spec with_fill(sparkline(), spark_fill()) -> sparkline().
with_fill(S, Fill) ->
    {sparkline, erlang:element(2, S), erlang:element(3, S), Fill, erlang:element(5, S), erlang:element(6, S), erlang:element(7, S)}.

-file("src/etui/widgets/sparkline.gleam", 58).
-spec with_max(sparkline(), integer()) -> sparkline().
with_max(S, Max) ->
    {sparkline, erlang:element(2, S), Max, erlang:element(4, S), erlang:element(5, S), erlang:element(6, S), erlang:element(7, S)}.

-file("src/etui/widgets/sparkline.gleam", 62).
-spec with_bg(sparkline(), etui@style:color()) -> sparkline().
with_bg(S, Bg) ->
    {sparkline, erlang:element(2, S), erlang:element(3, S), erlang:element(4, S), Bg, erlang:element(6, S), erlang:element(7, S)}.

-file("src/etui/widgets/sparkline.gleam", 66).
-spec with_period(sparkline(), integer()) -> sparkline().
with_period(S, Period) ->
    {sparkline, erlang:element(2, S), erlang:element(3, S), erlang:element(4, S), erlang:element(5, S), erlang:element(6, S), gleam@int:max(1, Period)}.

-file("src/etui/widgets/sparkline.gleam", 70).
-spec with_modifier(sparkline(), etui@style:modifier()) -> sparkline().
with_modifier(S, M) ->
    {sparkline, erlang:element(2, S), erlang:element(3, S), erlang:element(4, S), erlang:element(5, S), M, erlang:element(7, S)}.

-file("src/etui/widgets/sparkline.gleam", 74).
-spec with_style(sparkline(), etui@style:style()) -> sparkline().
with_style(S, St) ->
    {sparkline, erlang:element(2, S), erlang:element(3, S), erlang:element(4, S), erlang:element(3, St), erlang:element(4, St), erlang:element(7, S)}.

-file("src/etui/widgets/sparkline.gleam", 149).
-spec cell_color(spark_fill(), integer(), integer(), integer(), integer()) -> etui@style:color().
cell_color(Fill, X, Width, Frame, Period) ->
    P = gleam@int:max(1, Period),
    W = gleam@int:max(1, Width),
    case Fill of
        {spark_solid, C} ->
            C;

        {spark_gradient, Stops} ->
            etui@color:gradient(Stops, X, W - 1);

        {spark_animated, Stops@1} ->
            Offset = case P of
                0 ->
                    0;

                _value ->
                    (Frame * W) div _value
            end,
            etui@color:gradient(Stops@1, case W of
                0 ->
                    0;

                _value@1 ->
                    (X + Offset) rem _value@1
            end, W - 1);

        spark_rainbow ->
            etui@color:hue_to_rgb(case W of
                0 ->
                    0;

                _value@2 ->
                    (X * 360) div _value@2
            end);

        spark_animated_rainbow ->
            etui@color:hue_to_rgb((case W of
                0 ->
                    0;

                _value@3 ->
                    (X * 360) div _value@3
            end + case P of
                0 ->
                    0;

                _value@4 ->
                    (Frame * 360) div _value@4
            end) rem 360)
    end.

-file("src/etui/widgets/sparkline.gleam", 135).
-spec bar_char(integer()) -> binary().
bar_char(Level) ->
    case Level of
        0 ->
            ~" ";

        1 ->
            ~"▁";

        2 ->
            ~"▂";

        3 ->
            ~"▃";

        4 ->
            ~"▄";

        5 ->
            ~"▅";

        6 ->
            ~"▆";

        7 ->
            ~"▇";

        _ ->
            ~"█"
    end.

-file("src/etui/widgets/sparkline.gleam", 100).
-spec render_cols(etui@buffer:buffer(), etui@geometry:rect(), sparkline(), list(integer()), integer(), integer(), integer(), integer()) -> etui@buffer:buffer().
render_cols(Buf, Area, S, Data, X, Width, Max, Frame) ->
    case X >= Width of
        true ->
            Buf;

        false ->
            Val = case Data of
                [V | _] ->
                    V;

                [] ->
                    0
            end,
            Rest = case Data of
                [_ | R] ->
                    R;

                [] ->
                    []
            end,
            Level = gleam@int:min(8, case gleam@int:max(1, Max) of
                0 ->
                    0;

                _value ->
                    (Val * 8) div _value
            end),
            Ch = bar_char(Level),
            Fg = cell_color(erlang:element(4, S), X, Width, Frame, erlang:element(7, S)),
            Pos = {position, erlang:element(2, erlang:element(2, Area)) + X, erlang:element(3, erlang:element(2, Area))},
            Buf2 = etui@buffer:set_string(Buf, Pos, Ch, etui@style:new(Fg, erlang:element(5, S), erlang:element(6, S))),
            render_cols(Buf2, Area, S, Rest, X + 1, Width, Max, Frame)
    end.

-file("src/etui/widgets/sparkline.gleam", 82).
-spec render(etui@buffer:buffer(), etui@geometry:rect(), sparkline(), integer()) -> etui@buffer:buffer().
-doc(~" Render the sparkline. `frame` drives animated fills.").
render(Buf, Area, S, Frame) ->
    case (erlang:element(2, erlang:element(3, Area)) =< 0) orelse (erlang:element(3, erlang:element(3, Area)) =< 0) of
        true ->
            Buf;

        false ->
            Max = case erlang:element(3, S) of
                0 ->
                    gleam@list:fold(erlang:element(2, S), 1, fun gleam@int:max/2);

                M ->
                    gleam@int:max(1, M)
            end,
            render_cols(Buf, Area, S, erlang:element(2, S), 0, erlang:element(2, erlang:element(3, Area)), Max, Frame)
    end.

