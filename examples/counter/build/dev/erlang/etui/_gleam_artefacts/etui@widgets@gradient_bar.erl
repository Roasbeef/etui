-module(etui@widgets@gradient_bar).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([gradient_bar_new/1, animated_gradient_bar_new/1, rainbow_bar/0, animated_rainbow_bar/0, pulse_bar/1, gradient_progress_new/2, with_percent/2, with_chars/3, with_period/2, with_modifier/2, with_bg/2, render/4]).
-export_type([gradient_fill/0, gradient_bar/0]).

-type gradient_fill() :: {linear_gradient, list(etui@style:color())} | {animated_linear, list(etui@style:color())} | rainbow | animated_rainbow | {pulse, etui@style:color()}.

-type gradient_bar() :: {gradient_bar, gradient_fill(), binary(), binary(), integer(), etui@style:modifier(), etui@style:color(), integer()}.

-file("src/etui/widgets/gradient_bar.gleam", 41).
-spec gradient_bar_new(list(etui@style:color())) -> gradient_bar().
-doc(~" Static linear gradient bar (full width).").
gradient_bar_new(Stops) ->
    {gradient_bar, {linear_gradient, Stops}, ~"█", ~"░", 100, etui@style:none(), default, 60}.

-file("src/etui/widgets/gradient_bar.gleam", 54).
-spec animated_gradient_bar_new(list(etui@style:color())) -> gradient_bar().
-doc(~" Animated (scrolling) gradient bar (full width).").
animated_gradient_bar_new(Stops) ->
    {gradient_bar, {animated_linear, Stops}, ~"█", ~"░", 100, etui@style:none(), default, 60}.

-file("src/etui/widgets/gradient_bar.gleam", 67).
-spec rainbow_bar() -> gradient_bar().
-doc(~" Static rainbow bar (full width).").
rainbow_bar() ->
    {gradient_bar, rainbow, ~"█", ~" ", 100, etui@style:none(), default, 60}.

-file("src/etui/widgets/gradient_bar.gleam", 80).
-spec animated_rainbow_bar() -> gradient_bar().
-doc(~" Animated (rotating) rainbow bar (full width).").
animated_rainbow_bar() ->
    {gradient_bar, animated_rainbow, ~"█", ~" ", 100, etui@style:none(), default, 60}.

-file("src/etui/widgets/gradient_bar.gleam", 93).
-spec pulse_bar(etui@style:color()) -> gradient_bar().
-doc(~" Pulsing single-color bar (full width).").
pulse_bar(Base) ->
    {gradient_bar, {pulse, Base}, ~"█", ~" ", 100, etui@style:none(), default, 30}.

-file("src/etui/widgets/gradient_bar.gleam", 106).
-spec gradient_progress_new(list(etui@style:color()), integer()) -> gradient_bar().
-doc(~" Gradient progress bar: partial fill, static gradient.").
gradient_progress_new(Stops, Percent) ->
    {gradient_bar, {linear_gradient, Stops}, ~"█", ~"░", gleam@int:clamp(Percent, 0, 100), etui@style:none(), default, 60}.

-file("src/etui/widgets/gradient_bar.gleam", 124).
-spec with_percent(gradient_bar(), integer()) -> gradient_bar().
with_percent(G, Pct) ->
    {gradient_bar, erlang:element(2, G), erlang:element(3, G), erlang:element(4, G), gleam@int:clamp(Pct, 0, 100), erlang:element(6, G), erlang:element(7, G), erlang:element(8, G)}.

-file("src/etui/widgets/gradient_bar.gleam", 128).
-spec with_chars(gradient_bar(), binary(), binary()) -> gradient_bar().
with_chars(G, Filled, Empty) ->
    {gradient_bar, erlang:element(2, G), Filled, Empty, erlang:element(5, G), erlang:element(6, G), erlang:element(7, G), erlang:element(8, G)}.

-file("src/etui/widgets/gradient_bar.gleam", 136).
-spec with_period(gradient_bar(), integer()) -> gradient_bar().
with_period(G, Period) ->
    {gradient_bar, erlang:element(2, G), erlang:element(3, G), erlang:element(4, G), erlang:element(5, G), erlang:element(6, G), erlang:element(7, G), gleam@int:max(1, Period)}.

-file("src/etui/widgets/gradient_bar.gleam", 140).
-spec with_modifier(gradient_bar(), etui@style:modifier()) -> gradient_bar().
with_modifier(G, M) ->
    {gradient_bar, erlang:element(2, G), erlang:element(3, G), erlang:element(4, G), erlang:element(5, G), M, erlang:element(7, G), erlang:element(8, G)}.

-file("src/etui/widgets/gradient_bar.gleam", 144).
-spec with_bg(gradient_bar(), etui@style:color()) -> gradient_bar().
with_bg(G, Bg) ->
    {gradient_bar, erlang:element(2, G), erlang:element(3, G), erlang:element(4, G), erlang:element(5, G), erlang:element(6, G), Bg, erlang:element(8, G)}.

-file("src/etui/widgets/gradient_bar.gleam", 218).
-spec cell_color(gradient_fill(), integer(), integer(), integer(), integer()) -> etui@style:color().
cell_color(Fill, X, Width, Frame, Period) ->
    P = gleam@int:max(1, Period),
    W = gleam@int:max(1, Width),
    case Fill of
        {linear_gradient, Stops} ->
            etui@color:gradient(Stops, X, W - 1);

        {animated_linear, Stops@1} ->
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

        rainbow ->
            etui@color:hue_to_rgb(case W of
                0 ->
                    0;

                _value@2 ->
                    (X * 360) div _value@2
            end);

        animated_rainbow ->
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
            end) rem 360);

        {pulse, Base} ->
            etui@color:pulse(Base, Frame + case W of
                0 ->
                    0;

                _value@5 ->
                    (X * P) div _value@5
            end, P)
    end.

-file("src/etui/widgets/gradient_bar.gleam", 186).
-spec render_row_cells(etui@buffer:buffer(), etui@geometry:rect(), gradient_bar(), integer(), integer(), integer(), integer(), integer()) -> etui@buffer:buffer().
render_row_cells(Buf, Area, G, Frame, Width, Fill_width, X, Y) ->
    case X >= Width of
        true ->
            Buf;

        false ->
            Pos = {position, erlang:element(2, erlang:element(2, Area)) + X, erlang:element(3, erlang:element(2, Area)) + Y},
            {Sym, Fg} = case X < Fill_width of
                true ->
                    C = cell_color(erlang:element(2, G), X, Fill_width, Frame, erlang:element(8, G)),
                    {erlang:element(3, G), C};

                false ->
                    {erlang:element(4, G), default}
            end,
            Buf2 = etui@buffer:set_string(Buf, Pos, Sym, etui@style:new(Fg, erlang:element(7, G), erlang:element(6, G))),
            render_row_cells(Buf2, Area, G, Frame, Width, Fill_width, X + 1, Y)
    end.

-file("src/etui/widgets/gradient_bar.gleam", 168).
-spec render_rows(etui@buffer:buffer(), etui@geometry:rect(), gradient_bar(), integer(), integer(), integer(), integer()) -> etui@buffer:buffer().
render_rows(Buf, Area, G, Frame, Width, Fill_width, Y) ->
    case Y >= erlang:element(3, erlang:element(3, Area)) of
        true ->
            Buf;

        false ->
            Buf2 = render_row_cells(Buf, Area, G, Frame, Width, Fill_width, 0, Y),
            render_rows(Buf2, Area, G, Frame, Width, Fill_width, Y + 1)
    end.

-file("src/etui/widgets/gradient_bar.gleam", 152).
-spec render(etui@buffer:buffer(), etui@geometry:rect(), gradient_bar(), integer()) -> etui@buffer:buffer().
-doc(~" Render the gradient bar into `buf` at `area`. `frame` drives animation.").
render(Buf, Area, G, Frame) ->
    case (erlang:element(2, erlang:element(3, Area)) =< 0) orelse (erlang:element(3, erlang:element(3, Area)) =< 0) of
        true ->
            Buf;

        false ->
            Width = erlang:element(2, erlang:element(3, Area)),
            Fill_width = (Width * gleam@int:clamp(erlang:element(5, G), 0, 100)) div 100,
            render_rows(Buf, Area, G, Frame, Width, Fill_width, 0)
    end.

