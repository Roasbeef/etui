-module(etui@widgets@scrollbar).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([scrollbar_new/3, with_chars/3, with_arrows/3, with_colors/3, with_thumb_colors/3, render_vertical/3, render_horizontal/3]).
-export_type([scrollbar/0]).

-type scrollbar() :: {scrollbar, integer(), integer(), integer(), binary(), binary(), binary(), binary(), etui@style:color(), etui@style:color(), etui@style:color(), etui@style:color()}.

-file("src/etui/widgets/scrollbar.gleam", 48).
-spec scrollbar_new(integer(), integer(), integer()) -> scrollbar().
-doc(~" New scrollbar. `total` = total items, `visible` = viewport size,
 `offset` = first visible item index.").
scrollbar_new(Total, Visible, Offset) ->
    {scrollbar, gleam@int:max(1, Total), gleam@int:max(1, Visible), gleam@int:max(0, Offset), ~"░", ~"█", ~"▲", ~"▼", default, default, default, default}.

-file("src/etui/widgets/scrollbar.gleam", 65).
-spec with_chars(scrollbar(), binary(), binary()) -> scrollbar().
-doc(~" Override track and thumb characters.").
with_chars(S, Track, Thumb) ->
    {scrollbar, erlang:element(2, S), erlang:element(3, S), erlang:element(4, S), Track, Thumb, erlang:element(7, S), erlang:element(8, S), erlang:element(9, S), erlang:element(10, S), erlang:element(11, S), erlang:element(12, S)}.

-file("src/etui/widgets/scrollbar.gleam", 70).
-spec with_arrows(scrollbar(), binary(), binary()) -> scrollbar().
-doc(~" Override arrow characters. Pass `\"\"` to hide arrows.").
with_arrows(S, Start, End_ch) ->
    {scrollbar, erlang:element(2, S), erlang:element(3, S), erlang:element(4, S), erlang:element(5, S), erlang:element(6, S), Start, End_ch, erlang:element(9, S), erlang:element(10, S), erlang:element(11, S), erlang:element(12, S)}.

-file("src/etui/widgets/scrollbar.gleam", 75).
-spec with_colors(scrollbar(), etui@style:color(), etui@style:color()) -> scrollbar().
-doc(~" Set colors for the track.").
with_colors(S, Fg, Bg) ->
    {scrollbar, erlang:element(2, S), erlang:element(3, S), erlang:element(4, S), erlang:element(5, S), erlang:element(6, S), erlang:element(7, S), erlang:element(8, S), Fg, Bg, erlang:element(11, S), erlang:element(12, S)}.

-file("src/etui/widgets/scrollbar.gleam", 84).
-spec with_thumb_colors(scrollbar(), etui@style:color(), etui@style:color()) -> scrollbar().
-doc(~" Set colors for the thumb.").
with_thumb_colors(S, Fg, Bg) ->
    {scrollbar, erlang:element(2, S), erlang:element(3, S), erlang:element(4, S), erlang:element(5, S), erlang:element(6, S), erlang:element(7, S), erlang:element(8, S), erlang:element(9, S), erlang:element(10, S), Fg, Bg}.

-file("src/etui/widgets/scrollbar.gleam", 98).
-spec is_scrollable(scrollbar()) -> boolean().
is_scrollable(S) ->
    erlang:element(2, S) > erlang:element(3, S).

-file("src/etui/widgets/scrollbar.gleam", 269).
-spec render_vertical_track(etui@buffer:buffer(), etui@geometry:rect(), scrollbar(), integer(), integer(), integer(), integer()) -> etui@buffer:buffer().
render_vertical_track(Buf, Area, S, Track_len, Thumb_start, Thumb_size, I) ->
    case I >= Track_len of
        true ->
            Buf;

        false ->
            Pos = {position, erlang:element(2, erlang:element(2, Area)), erlang:element(3, erlang:element(2, Area)) + I},
            Is_thumb = (I >= Thumb_start) andalso (I < (Thumb_start + Thumb_size)),
            {Ch, Fg, Bg} = case Is_thumb of
                true ->
                    {erlang:element(6, S), erlang:element(11, S), erlang:element(12, S)};

                false ->
                    {erlang:element(5, S), erlang:element(9, S), erlang:element(10, S)}
            end,
            Buf2 = etui@buffer:set_string(Buf, Pos, Ch, etui@style:new(Fg, Bg, etui@style:none())),
            render_vertical_track(Buf2, Area, S, Track_len, Thumb_start, Thumb_size, I + 1)
    end.

-file("src/etui/widgets/scrollbar.gleam", 253).
-spec thumb_geometry(scrollbar(), integer()) -> {integer(), integer()}.
-doc(~" Compute thumb start position and size within a track of `track_len` cells.").
thumb_geometry(S, Track_len) ->
    Total = gleam@int:max(1, erlang:element(2, S)),
    Visible = gleam@int:clamp(erlang:element(3, S), 1, Total),
    Offset = gleam@int:clamp(erlang:element(4, S), 0, Total - Visible),
    Thumb_size = gleam@int:max(1, case Total of
        0 ->
            0;

        _value ->
            (Track_len * Visible) div _value
    end),
    Scrollable = Total - Visible,
    Thumb_start = case Scrollable of
        0 ->
            0;

        _ ->
            case Scrollable of
                0 ->
                    0;

                _value@1 ->
                    ((Track_len - Thumb_size) * Offset) div _value@1
            end
    end,
    {Thumb_start, Thumb_size}.

-file("src/etui/widgets/scrollbar.gleam", 108).
-spec render_vertical(etui@buffer:buffer(), etui@geometry:rect(), scrollbar()) -> etui@buffer:buffer().
-doc(~" Render a vertical scrollbar into the first column of `area`.
 Arrow characters (if non-empty) occupy the top and bottom cells;
 the track fills the remaining height.

 Draws nothing when `total <= visible`: there is nothing to scroll, so the
 column is left as the caller drew it.").
render_vertical(Buf, Area, S) ->
    case ((erlang:element(3, erlang:element(3, Area)) =< 0) orelse (erlang:element(2, erlang:element(3, Area)) =< 0)) orelse not is_scrollable(S) of
        true ->
            Buf;

        false ->
            Has_start = erlang:element(7, S) /= ~"",
            Has_end = erlang:element(8, S) /= ~"",
            Arrow_top = case Has_start of
                true ->
                    1;

                false ->
                    0
            end,
            Arrow_bot = case Has_end of
                true ->
                    1;

                false ->
                    0
            end,
            Track_len = gleam@int:max(0, (erlang:element(3, erlang:element(3, Area)) - Arrow_top) - Arrow_bot),
            Buf@1 = case Has_start of
                false ->
                    Buf;

                true ->
                    etui@buffer:set_string(Buf, {position, erlang:element(2, erlang:element(2, Area)), erlang:element(3, erlang:element(2, Area))}, erlang:element(7, S), etui@style:new(erlang:element(9, S), erlang:element(10, S), etui@style:none()))
            end,
            Buf@2 = case Has_end of
                false ->
                    Buf@1;

                true ->
                    etui@buffer:set_string(Buf@1, {position, erlang:element(2, erlang:element(2, Area)), (erlang:element(3, erlang:element(2, Area)) + erlang:element(3, erlang:element(3, Area))) - 1}, erlang:element(8, S), etui@style:new(erlang:element(9, S), erlang:element(10, S), etui@style:none()))
            end,
            case Track_len =< 0 of
                true ->
                    Buf@2;

                false ->
                    Track_area = etui@geometry:rect_new(erlang:element(2, erlang:element(2, Area)), erlang:element(3, erlang:element(2, Area)) + Arrow_top, erlang:element(2, erlang:element(3, Area)), Track_len),
                    {Thumb_start, Thumb_size} = thumb_geometry(S, Track_len),
                    render_vertical_track(Buf@2, Track_area, S, Track_len, Thumb_start, Thumb_size, 0)
            end
    end.

-file("src/etui/widgets/scrollbar.gleam", 302).
-spec render_horizontal_track(etui@buffer:buffer(), etui@geometry:rect(), scrollbar(), integer(), integer(), integer(), integer()) -> etui@buffer:buffer().
render_horizontal_track(Buf, Area, S, Track_len, Thumb_start, Thumb_size, I) ->
    case I >= Track_len of
        true ->
            Buf;

        false ->
            Pos = {position, erlang:element(2, erlang:element(2, Area)) + I, erlang:element(3, erlang:element(2, Area))},
            Is_thumb = (I >= Thumb_start) andalso (I < (Thumb_start + Thumb_size)),
            {Ch, Fg, Bg} = case Is_thumb of
                true ->
                    {erlang:element(6, S), erlang:element(11, S), erlang:element(12, S)};

                false ->
                    {erlang:element(5, S), erlang:element(9, S), erlang:element(10, S)}
            end,
            Buf2 = etui@buffer:set_string(Buf, Pos, Ch, etui@style:new(Fg, Bg, etui@style:none())),
            render_horizontal_track(Buf2, Area, S, Track_len, Thumb_start, Thumb_size, I + 1)
    end.

-file("src/etui/widgets/scrollbar.gleam", 181).
-spec render_horizontal(etui@buffer:buffer(), etui@geometry:rect(), scrollbar()) -> etui@buffer:buffer().
-doc(~" Render a horizontal scrollbar into the first row of `area`.
 Arrow characters (if non-empty) occupy the leftmost and rightmost cells;
 the track fills the remaining width.

 Draws nothing when `total <= visible`, same as `render_vertical`.").
render_horizontal(Buf, Area, S) ->
    case ((erlang:element(3, erlang:element(3, Area)) =< 0) orelse (erlang:element(2, erlang:element(3, Area)) =< 0)) orelse not is_scrollable(S) of
        true ->
            Buf;

        false ->
            Has_start = erlang:element(7, S) /= ~"",
            Has_end = erlang:element(8, S) /= ~"",
            Arrow_left = case Has_start of
                true ->
                    1;

                false ->
                    0
            end,
            Arrow_right = case Has_end of
                true ->
                    1;

                false ->
                    0
            end,
            Track_len = gleam@int:max(0, (erlang:element(2, erlang:element(3, Area)) - Arrow_left) - Arrow_right),
            Buf@1 = case Has_start of
                false ->
                    Buf;

                true ->
                    etui@buffer:set_string(Buf, {position, erlang:element(2, erlang:element(2, Area)), erlang:element(3, erlang:element(2, Area))}, erlang:element(7, S), etui@style:new(erlang:element(9, S), erlang:element(10, S), etui@style:none()))
            end,
            Buf@2 = case Has_end of
                false ->
                    Buf@1;

                true ->
                    etui@buffer:set_string(Buf@1, {position, (erlang:element(2, erlang:element(2, Area)) + erlang:element(2, erlang:element(3, Area))) - 1, erlang:element(3, erlang:element(2, Area))}, erlang:element(8, S), etui@style:new(erlang:element(9, S), erlang:element(10, S), etui@style:none()))
            end,
            case Track_len =< 0 of
                true ->
                    Buf@2;

                false ->
                    Track_area = etui@geometry:rect_new(erlang:element(2, erlang:element(2, Area)) + Arrow_left, erlang:element(3, erlang:element(2, Area)), Track_len, erlang:element(3, erlang:element(3, Area))),
                    {Thumb_start, Thumb_size} = thumb_geometry(S, Track_len),
                    render_horizontal_track(Buf@2, Track_area, S, Track_len, Thumb_start, Thumb_size, 0)
            end
    end.

