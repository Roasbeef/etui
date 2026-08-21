-module(etui@widgets@hbar).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([hbar_new/1, item/2, with_fill/2, with_max/2, with_label_width/2, with_show_value/2, with_chars/3, with_period/2, with_bg/2, with_style/2, render/4]).
-export_type([h_bar_fill/0, h_bar_item/0, h_bar/0]).

-type h_bar_fill() :: {h_bar_solid, list(etui@style:color())} | {h_bar_gradient, list(etui@style:color())} | h_bar_rainbow | h_bar_animated_rainbow.

-type h_bar_item() :: {h_bar_item, binary(), integer()}.

-type h_bar() :: {h_bar, list(h_bar_item()), integer(), h_bar_fill(), integer(), boolean(), binary(), binary(), etui@style:color(), integer()}.

-file("src/etui/widgets/hbar.gleam", 50).
-spec hbar_new(list(h_bar_item())) -> h_bar().
hbar_new(Items) ->
    {h_bar, Items, 0, h_bar_rainbow, 0, true, ~"█", ~"░", default, 60}.

-file("src/etui/widgets/hbar.gleam", 64).
-spec item(binary(), integer()) -> h_bar_item().
item(Label, Value) ->
    {h_bar_item, Label, Value}.

-file("src/etui/widgets/hbar.gleam", 68).
-spec with_fill(h_bar(), h_bar_fill()) -> h_bar().
with_fill(H, Fill) ->
    {h_bar, erlang:element(2, H), erlang:element(3, H), Fill, erlang:element(5, H), erlang:element(6, H), erlang:element(7, H), erlang:element(8, H), erlang:element(9, H), erlang:element(10, H)}.

-file("src/etui/widgets/hbar.gleam", 72).
-spec with_max(h_bar(), integer()) -> h_bar().
with_max(H, Max) ->
    {h_bar, erlang:element(2, H), gleam@int:max(1, Max), erlang:element(4, H), erlang:element(5, H), erlang:element(6, H), erlang:element(7, H), erlang:element(8, H), erlang:element(9, H), erlang:element(10, H)}.

-file("src/etui/widgets/hbar.gleam", 76).
-spec with_label_width(h_bar(), integer()) -> h_bar().
with_label_width(H, W) ->
    {h_bar, erlang:element(2, H), erlang:element(3, H), erlang:element(4, H), gleam@int:max(0, W), erlang:element(6, H), erlang:element(7, H), erlang:element(8, H), erlang:element(9, H), erlang:element(10, H)}.

-file("src/etui/widgets/hbar.gleam", 80).
-spec with_show_value(h_bar(), boolean()) -> h_bar().
with_show_value(H, Show) ->
    {h_bar, erlang:element(2, H), erlang:element(3, H), erlang:element(4, H), erlang:element(5, H), Show, erlang:element(7, H), erlang:element(8, H), erlang:element(9, H), erlang:element(10, H)}.

-file("src/etui/widgets/hbar.gleam", 84).
-spec with_chars(h_bar(), binary(), binary()) -> h_bar().
with_chars(H, Bar, Empty) ->
    {h_bar, erlang:element(2, H), erlang:element(3, H), erlang:element(4, H), erlang:element(5, H), erlang:element(6, H), Bar, Empty, erlang:element(9, H), erlang:element(10, H)}.

-file("src/etui/widgets/hbar.gleam", 88).
-spec with_period(h_bar(), integer()) -> h_bar().
with_period(H, Period) ->
    {h_bar, erlang:element(2, H), erlang:element(3, H), erlang:element(4, H), erlang:element(5, H), erlang:element(6, H), erlang:element(7, H), erlang:element(8, H), erlang:element(9, H), gleam@int:max(1, Period)}.

-file("src/etui/widgets/hbar.gleam", 92).
-spec with_bg(h_bar(), etui@style:color()) -> h_bar().
with_bg(H, Bg) ->
    {h_bar, erlang:element(2, H), erlang:element(3, H), erlang:element(4, H), erlang:element(5, H), erlang:element(6, H), erlang:element(7, H), erlang:element(8, H), Bg, erlang:element(10, H)}.

-file("src/etui/widgets/hbar.gleam", 96).
-spec with_style(h_bar(), etui@style:style()) -> h_bar().
with_style(H, S) ->
    {h_bar, erlang:element(2, H), erlang:element(3, H), erlang:element(4, H), erlang:element(5, H), erlang:element(6, H), erlang:element(7, H), erlang:element(8, H), erlang:element(3, S), erlang:element(10, H)}.

-file("src/etui/widgets/hbar.gleam", 268).
-spec render_empty_loop(etui@buffer:buffer(), h_bar(), integer(), integer(), integer(), integer()) -> etui@buffer:buffer().
render_empty_loop(Buf, H, Base_x, Y, Count, I) ->
    case I >= Count of
        true ->
            Buf;

        false ->
            Buf2 = etui@buffer:set_string(Buf, {position, Base_x + I, Y}, erlang:element(8, H), etui@style:new(default, erlang:element(9, H), etui@style:none())),
            render_empty_loop(Buf2, H, Base_x, Y, Count, I + 1)
    end.

-file("src/etui/widgets/hbar.gleam", 258).
-spec render_empty(etui@buffer:buffer(), h_bar(), integer(), integer(), integer()) -> etui@buffer:buffer().
render_empty(Buf, H, Base_x, Y, Count) ->
    render_empty_loop(Buf, H, Base_x, Y, Count, 0).

-file("src/etui/widgets/hbar.gleam", 323).
-spec color_at(list(etui@style:color()), integer()) -> etui@style:color().
color_at(Colors, N) ->
    case {Colors, N} of
        {[], _} ->
            default;

        {[C | _], 0} ->
            C;

        {[_ | Rest], _} ->
            color_at(Rest, N - 1)
    end.

-file("src/etui/widgets/hbar.gleam", 315).
-spec nth_color(list(etui@style:color()), integer()) -> etui@style:color().
nth_color(Colors, N) ->
    Len = erlang:length(Colors),
    case Len of
        0 ->
            default;

        _ ->
            color_at(Colors, case Len of
                0 ->
                    0;

                _value ->
                    N rem _value
            end)
    end.

-file("src/etui/widgets/hbar.gleam", 294).
-spec cell_color(h_bar_fill(), integer(), integer(), integer(), integer(), integer(), integer()) -> etui@style:color().
cell_color(Fill, Bar_idx, N, X, Bar_w, Frame, Period) ->
    P = gleam@int:max(1, Period),
    Nb = gleam@int:max(1, N),
    W = gleam@int:max(1, Bar_w),
    case Fill of
        {h_bar_solid, Colors} ->
            nth_color(Colors, Bar_idx);

        {h_bar_gradient, Stops} ->
            etui@color:gradient(Stops, X, W - 1);

        h_bar_rainbow ->
            etui@color:hue_to_rgb(case Nb of
                0 ->
                    0;

                _value ->
                    (Bar_idx * 360) div _value
            end);

        h_bar_animated_rainbow ->
            etui@color:hue_to_rgb((case Nb of
                0 ->
                    0;

                _value@1 ->
                    (Bar_idx * 360) div _value@1
            end + case P of
                0 ->
                    0;

                _value@2 ->
                    (Frame * 360) div _value@2
            end) rem 360)
    end.

-file("src/etui/widgets/hbar.gleam", 219).
-spec render_filled_loop(etui@buffer:buffer(), h_bar(), integer(), integer(), integer(), integer(), integer(), integer(), integer(), integer()) -> etui@buffer:buffer().
render_filled_loop(Buf, H, Bar_idx, N, Base_x, Y, Count, Bar_w, Frame, I) ->
    case I >= Count of
        true ->
            Buf;

        false ->
            Fg = cell_color(erlang:element(4, H), Bar_idx, N, I, Bar_w, Frame, erlang:element(10, H)),
            Buf2 = etui@buffer:set_string(Buf, {position, Base_x + I, Y}, erlang:element(7, H), etui@style:new(Fg, erlang:element(9, H), etui@style:none())),
            render_filled_loop(Buf2, H, Bar_idx, N, Base_x, Y, Count, Bar_w, Frame, I + 1)
    end.

-file("src/etui/widgets/hbar.gleam", 205).
-spec render_filled(etui@buffer:buffer(), h_bar(), integer(), integer(), integer(), integer(), integer(), integer(), integer()) -> etui@buffer:buffer().
render_filled(Buf, H, Bar_idx, N, Base_x, Y, Count, Bar_w, Frame) ->
    render_filled_loop(Buf, H, Bar_idx, N, Base_x, Y, Count, Bar_w, Frame, 0).

-file("src/etui/widgets/hbar.gleam", 161).
-spec render_row(etui@buffer:buffer(), etui@geometry:rect(), h_bar(), h_bar_item(), integer(), integer(), integer(), integer(), integer(), integer(), integer()) -> etui@buffer:buffer().
render_row(Buf, Area, H, It, Idx, N, Max, Lw, Val_w, Y, Frame) ->
    Label = etui@text:pad_right(etui@text:truncate(erlang:element(2, It), Lw, ~""), Lw),
    Buf@1 = etui@buffer:set_string(Buf, {position, erlang:element(2, erlang:element(2, Area)), Y}, Label, etui@style:new(default, default, etui@style:none())),
    Bar_x = (erlang:element(2, erlang:element(2, Area)) + Lw) + 1,
    Bar_w = gleam@int:max(0, ((erlang:element(2, erlang:element(3, Area)) - Lw) - 1) - Val_w),
    Filled = gleam@int:clamp(case gleam@int:max(1, Max) of
        0 ->
            0;

        _value ->
            (erlang:element(3, It) * Bar_w) div _value
    end, 0, Bar_w),
    Empty = Bar_w - Filled,
    Buf@2 = render_filled(Buf@1, H, Idx, N, Bar_x, Y, Filled, Bar_w, Frame),
    Buf@3 = render_empty(Buf@2, H, Bar_x + Filled, Y, Empty),
    case erlang:element(6, H) andalso (Val_w > 0) of
        false ->
            Buf@3;

        true ->
            etui@buffer:set_string(Buf@3, {position, (Bar_x + Bar_w) + 1, Y}, erlang:integer_to_binary(erlang:element(3, It)), etui@style:new(default, default, etui@style:none()))
    end.

-file("src/etui/widgets/hbar.gleam", 133).
-spec render_rows(etui@buffer:buffer(), etui@geometry:rect(), h_bar(), list(h_bar_item()), integer(), integer(), integer(), integer(), integer(), integer()) -> etui@buffer:buffer().
render_rows(Buf, Area, H, Items, Idx, N, Max, Lw, Val_w, Frame) ->
    case Items of
        [] ->
            Buf;

        [It | Rest] ->
            case Idx >= erlang:element(3, erlang:element(3, Area)) of
                true ->
                    Buf;

                false ->
                    Y = erlang:element(3, erlang:element(2, Area)) + Idx,
                    Buf2 = render_row(Buf, Area, H, It, Idx, N, Max, Lw, Val_w, Y, Frame),
                    render_rows(Buf2, Area, H, Rest, Idx + 1, N, Max, Lw, Val_w, Frame)
            end
    end.

-file("src/etui/widgets/hbar.gleam", 331).
-spec num_digits(integer()) -> integer().
num_digits(N) ->
    case N < 10 of
        true ->
            1;

        false ->
            1 + num_digits(N div 10)
    end.

-file("src/etui/widgets/hbar.gleam", 103).
-spec render(etui@buffer:buffer(), etui@geometry:rect(), h_bar(), integer()) -> etui@buffer:buffer().
render(Buf, Area, H, Frame) ->
    case (erlang:element(2, erlang:element(3, Area)) =< 0) orelse (erlang:element(3, erlang:element(3, Area)) =< 0) of
        true ->
            Buf;

        false ->
            Max = case erlang:element(3, H) of
                0 ->
                    gleam@list:fold(erlang:element(2, H), 1, fun(Acc, It) ->
                        gleam@int:max(Acc, erlang:element(3, It))
                    end);

                M ->
                    M
            end,
            Lw = case erlang:element(5, H) of
                0 ->
                    gleam@list:fold(erlang:element(2, H), 0, fun(Acc, It) ->
                        gleam@int:max(Acc, etui@text:cell_width(erlang:element(2, It)))
                    end);

                W ->
                    W
            end,
            Val_w = case erlang:element(6, H) of
                false ->
                    0;

                true ->
                    num_digits(Max) + 2
            end,
            N = erlang:length(erlang:element(2, H)),
            render_rows(Buf, Area, H, erlang:element(2, H), 0, N, Max, Lw, Val_w, Frame)
    end.

