-module(etui@widgets@popup).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([popup_new/2, with_title/2, with_border/2, with_style/3, with_colors/3, popup_rect/2, popup_area/2, render/3]).
-export_type([popup/0]).

-type popup() :: {popup, integer(), integer(), binary(), etui@widgets@block:border(), etui@style:color(), etui@style:color()}.

-file("src/etui/widgets/popup.gleam", 37).
-spec popup_new(integer(), integer()) -> popup().
-doc(~" New popup with given cell dimensions. Default: Rounded border, default colors.").
popup_new(Width, Height) ->
    {popup, Width, Height, ~"", rounded, default, default}.

-file("src/etui/widgets/popup.gleam", 49).
-spec with_title(popup(), binary()) -> popup().
-doc(~" Set the popup title (shown on top border).").
with_title(P, Title) ->
    {popup, erlang:element(2, P), erlang:element(3, P), Title, erlang:element(5, P), erlang:element(6, P), erlang:element(7, P)}.

-file("src/etui/widgets/popup.gleam", 54).
-spec with_border(popup(), etui@widgets@block:border()) -> popup().
-doc(~" Set the border style.").
with_border(P, Border) ->
    {popup, erlang:element(2, P), erlang:element(3, P), erlang:element(4, P), Border, erlang:element(6, P), erlang:element(7, P)}.

-file("src/etui/widgets/popup.gleam", 59).
-spec with_style(popup(), etui@style:color(), etui@style:color()) -> popup().
-doc(~" Set foreground and background colors.").
with_style(P, Fg, Bg) ->
    {popup, erlang:element(2, P), erlang:element(3, P), erlang:element(4, P), erlang:element(5, P), Fg, Bg}.

-file("src/etui/widgets/popup.gleam", 63).
-spec with_colors(popup(), etui@style:color(), etui@style:color()) -> popup().
with_colors(P, Fg, Bg) ->
    {popup, erlang:element(2, P), erlang:element(3, P), erlang:element(4, P), erlang:element(5, P), Fg, Bg}.

-file("src/etui/widgets/popup.gleam", 114).
-spec int_clamp(integer(), integer(), integer()) -> integer().
int_clamp(V, Lo, Hi) ->
    case V < Lo of
        true ->
            Lo;

        false ->
            case V > Hi of
                true ->
                    Hi;

                false ->
                    V
            end
    end.

-file("src/etui/widgets/popup.gleam", 71).
-spec popup_rect(etui@geometry:rect(), popup()) -> etui@geometry:rect().
-doc(~" Centered rect for this popup within `screen`.").
popup_rect(Screen, P) ->
    W = int_clamp(erlang:element(2, P), 0, erlang:element(2, erlang:element(3, Screen))),
    H = int_clamp(erlang:element(3, P), 0, erlang:element(3, erlang:element(3, Screen))),
    X = erlang:element(2, erlang:element(2, Screen)) + ((erlang:element(2, erlang:element(3, Screen)) - W) div 2),
    Y = erlang:element(3, erlang:element(2, Screen)) + ((erlang:element(3, erlang:element(3, Screen)) - H) div 2),
    {rect, {position, X, Y}, {size, W, H}}.

-file("src/etui/widgets/popup.gleam", 106).
-spec to_block(popup()) -> etui@widgets@block:block().
to_block(P) ->
    _pipe = etui@widgets@block:block_new(),
    _pipe@1 = etui@widgets@block:with_border(_pipe, erlang:element(5, P)),
    _pipe@2 = etui@widgets@block:with_title(_pipe@1, erlang:element(4, P), top),
    _pipe@3 = etui@widgets@block:with_style(_pipe@2, erlang:element(6, P), erlang:element(7, P)),
    etui@widgets@block:with_bg_fill(_pipe@3).

-file("src/etui/widgets/popup.gleam", 83).
-spec popup_area(etui@geometry:rect(), popup()) -> etui@geometry:rect().
-doc(~" Inner content area (inside border and padding) for child widgets.").
popup_area(Screen, P) ->
    Outer = popup_rect(Screen, P),
    Blk = to_block(P),
    etui@widgets@block:inner(Outer, Blk).

-file("src/etui/widgets/popup.gleam", 93).
-spec render(etui@buffer:buffer(), etui@geometry:rect(), popup()) -> etui@buffer:buffer().
-doc(~" Render popup overlay. Draw child widgets into `popup_area` after this.").
render(Buf, Screen, P) ->
    Outer = popup_rect(Screen, P),
    Blk = to_block(P),
    etui@widgets@block:render(Buf, Outer, Blk).

