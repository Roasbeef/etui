-module(etui@widgets@chart).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([chart_new/1, with_fill/2, with_max/2, with_bar_width/2, with_gap/2, with_period/2, with_bg/2, with_style/2, render/4]).
-export_type([chart_fill/0, chart/0]).

-type chart_fill() :: {chart_solid, list(etui@style:color())} | {chart_gradient, list(etui@style:color())} | chart_rainbow | chart_animated_rainbow | {chart_vertical_gradient, list(etui@style:color())}.

-type chart() :: {chart, list(integer()), integer(), chart_fill(), integer(), integer(), binary(), etui@style:color(), integer()}.

-file("src/etui/widgets/chart.gleam", 48).
-spec chart_new(list(integer())) -> chart().
chart_new(Data) ->
    {chart, Data, 0, chart_rainbow, 2, 1, ~"█", default, 60}.

-file("src/etui/widgets/chart.gleam", 61).
-spec with_fill(chart(), chart_fill()) -> chart().
with_fill(C, Fill) ->
    {chart, erlang:element(2, C), erlang:element(3, C), Fill, erlang:element(5, C), erlang:element(6, C), erlang:element(7, C), erlang:element(8, C), erlang:element(9, C)}.

-file("src/etui/widgets/chart.gleam", 65).
-spec with_max(chart(), integer()) -> chart().
with_max(C, Max) ->
    {chart, erlang:element(2, C), gleam@int:max(1, Max), erlang:element(4, C), erlang:element(5, C), erlang:element(6, C), erlang:element(7, C), erlang:element(8, C), erlang:element(9, C)}.

-file("src/etui/widgets/chart.gleam", 69).
-spec with_bar_width(chart(), integer()) -> chart().
with_bar_width(C, W) ->
    {chart, erlang:element(2, C), erlang:element(3, C), erlang:element(4, C), gleam@int:max(1, W), erlang:element(6, C), erlang:element(7, C), erlang:element(8, C), erlang:element(9, C)}.

-file("src/etui/widgets/chart.gleam", 73).
-spec with_gap(chart(), integer()) -> chart().
with_gap(C, G) ->
    {chart, erlang:element(2, C), erlang:element(3, C), erlang:element(4, C), erlang:element(5, C), gleam@int:max(0, G), erlang:element(7, C), erlang:element(8, C), erlang:element(9, C)}.

-file("src/etui/widgets/chart.gleam", 77).
-spec with_period(chart(), integer()) -> chart().
with_period(C, Period) ->
    {chart, erlang:element(2, C), erlang:element(3, C), erlang:element(4, C), erlang:element(5, C), erlang:element(6, C), erlang:element(7, C), erlang:element(8, C), gleam@int:max(1, Period)}.

-file("src/etui/widgets/chart.gleam", 81).
-spec with_bg(chart(), etui@style:color()) -> chart().
with_bg(C, Bg) ->
    {chart, erlang:element(2, C), erlang:element(3, C), erlang:element(4, C), erlang:element(5, C), erlang:element(6, C), erlang:element(7, C), Bg, erlang:element(9, C)}.

-file("src/etui/widgets/chart.gleam", 85).
-spec with_style(chart(), etui@style:style()) -> chart().
with_style(C, S) ->
    {chart, erlang:element(2, C), erlang:element(3, C), erlang:element(4, C), erlang:element(5, C), erlang:element(6, C), erlang:element(7, C), erlang:element(3, S), erlang:element(9, C)}.

-file("src/etui/widgets/chart.gleam", 309).
-spec get_color_at(list(etui@style:color()), integer()) -> etui@style:color().
get_color_at(Colors, N) ->
    case {Colors, N} of
        {[], _} ->
            default;

        {[C | _], 0} ->
            C;

        {[_ | Rest], _} ->
            get_color_at(Rest, N - 1)
    end.

-file("src/etui/widgets/chart.gleam", 301).
-spec get_nth_color(list(etui@style:color()), integer()) -> etui@style:color().
get_nth_color(Colors, N) ->
    Len = erlang:length(Colors),
    case Len of
        0 ->
            default;

        _ ->
            get_color_at(Colors, case Len of
                0 ->
                    0;

                _value ->
                    N rem _value
            end)
    end.

-file("src/etui/widgets/chart.gleam", 278).
-spec bar_color(chart_fill(), integer(), integer(), integer(), integer(), integer(), integer()) -> etui@style:color().
bar_color(Fill, Bar_idx, N_bars, Dy, Height, Frame, Period) ->
    P = gleam@int:max(1, Period),
    N = gleam@int:max(1, N_bars),
    H = gleam@int:max(1, Height),
    case Fill of
        {chart_solid, Colors} ->
            get_nth_color(Colors, Bar_idx);

        {chart_gradient, Stops} ->
            etui@color:gradient(Stops, Bar_idx, N - 1);

        chart_rainbow ->
            etui@color:hue_to_rgb(case N of
                0 ->
                    0;

                _value ->
                    (Bar_idx * 360) div _value
            end);

        chart_animated_rainbow ->
            etui@color:hue_to_rgb((case N of
                0 ->
                    0;

                _value@1 ->
                    (Bar_idx * 360) div _value@1
            end + case P of
                0 ->
                    0;

                _value@2 ->
                    (Frame * 360) div _value@2
            end) rem 360);

        {chart_vertical_gradient, Stops@1} ->
            etui@color:gradient(Stops@1, (Height - 1) - Dy, H - 1)
    end.

-file("src/etui/widgets/chart.gleam", 226).
-spec render_bar_rows(etui@buffer:buffer(), etui@geometry:rect(), chart(), integer(), integer(), integer(), integer(), integer(), integer(), integer()) -> etui@buffer:buffer().
render_bar_rows(Buf, Area, C, Bar_idx, N_bars, X, Height, Filled_rows, Frame, Dy) ->
    case Dy >= Height of
        true ->
            Buf;

        false ->
            Rows_from_bottom = (Height - 1) - Dy,
            Is_filled = Rows_from_bottom < Filled_rows,
            Pos = {position, erlang:element(2, erlang:element(2, Area)) + X, erlang:element(3, erlang:element(2, Area)) + Dy},
            Buf2 = case Is_filled of
                true ->
                    Fg = bar_color(erlang:element(4, C), Bar_idx, N_bars, Dy, Height, Frame, erlang:element(9, C)),
                    etui@buffer:set_string(Buf, Pos, erlang:element(7, C), etui@style:new(Fg, erlang:element(8, C), etui@style:none()));

                false ->
                    Buf
            end,
            render_bar_rows(Buf2, Area, C, Bar_idx, N_bars, X, Height, Filled_rows, Frame, Dy + 1)
    end.

-file("src/etui/widgets/chart.gleam", 176).
-spec render_bar_cols_inner(etui@buffer:buffer(), etui@geometry:rect(), chart(), integer(), integer(), integer(), integer(), integer(), integer(), integer()) -> etui@buffer:buffer().
render_bar_cols_inner(Buf, Area, C, Bar_idx, N_bars, Col_start, Height, Filled_rows, Frame, Dc) ->
    case Dc >= erlang:element(5, C) of
        true ->
            Buf;

        false ->
            X = Col_start + Dc,
            case X >= erlang:element(2, erlang:element(3, Area)) of
                true ->
                    Buf;

                false ->
                    Buf2 = render_bar_rows(Buf, Area, C, Bar_idx, N_bars, X, Height, Filled_rows, Frame, 0),
                    render_bar_cols_inner(Buf2, Area, C, Bar_idx, N_bars, Col_start, Height, Filled_rows, Frame, Dc + 1)
            end
    end.

-file("src/etui/widgets/chart.gleam", 151).
-spec render_bar_col(etui@buffer:buffer(), etui@geometry:rect(), chart(), integer(), integer(), integer(), integer(), integer(), integer()) -> etui@buffer:buffer().
render_bar_col(Buf, Area, C, Bar_idx, N_bars, Col_start, Height, Filled_rows, Frame) ->
    render_bar_cols_inner(Buf, Area, C, Bar_idx, N_bars, Col_start, Height, Filled_rows, Frame, 0).

-file("src/etui/widgets/chart.gleam", 112).
-spec render_bars(etui@buffer:buffer(), etui@geometry:rect(), chart(), list(integer()), integer(), integer(), integer(), integer()) -> etui@buffer:buffer().
render_bars(Buf, Area, C, Data, Bar_idx, N_bars, Max, Frame) ->
    case Data of
        [] ->
            Buf;

        [Val | Rest] ->
            Col_start = Bar_idx * (erlang:element(5, C) + erlang:element(6, C)),
            case Col_start >= erlang:element(2, erlang:element(3, Area)) of
                true ->
                    Buf;

                false ->
                    H = erlang:element(3, erlang:element(3, Area)),
                    Filled_rows = case gleam@int:max(1, Max) of
                        0 ->
                            0;

                        _value ->
                            (Val * H) div _value
                    end,
                    Buf2 = render_bar_col(Buf, Area, C, Bar_idx, N_bars, Col_start, H, Filled_rows, Frame),
                    render_bars(Buf2, Area, C, Rest, Bar_idx + 1, N_bars, Max, Frame)
            end
    end.

-file("src/etui/widgets/chart.gleam", 93).
-spec render(etui@buffer:buffer(), etui@geometry:rect(), chart(), integer()) -> etui@buffer:buffer().
-doc(~" Render chart into `area`. `frame` drives animated fills.").
render(Buf, Area, C, Frame) ->
    case (erlang:element(2, erlang:element(3, Area)) =< 0) orelse (erlang:element(3, erlang:element(3, Area)) =< 0) of
        true ->
            Buf;

        false ->
            Max = case erlang:element(3, C) of
                0 ->
                    gleam@list:fold(erlang:element(2, C), 1, fun gleam@int:max/2);

                M ->
                    M
            end,
            N_bars = erlang:length(erlang:element(2, C)),
            render_bars(Buf, Area, C, erlang:element(2, C), 0, N_bars, Max, Frame)
    end.

