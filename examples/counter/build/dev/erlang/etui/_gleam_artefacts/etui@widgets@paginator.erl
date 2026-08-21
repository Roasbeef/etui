-module(etui@widgets@paginator).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([paginator_new/1, with_page_size/2, with_style/2, with_chars/3, with_colors/3, next_page/1, prev_page/1, go_to/2, set_item_count/2, slice/2, render/3]).
-export_type([paginator_style/0, paginator/0]).

-type paginator_style() :: dots | arabic.

-type paginator() :: {paginator, integer(), integer(), integer(), paginator_style(), binary(), binary(), etui@style:color(), etui@style:color()}.

-file("src/etui/widgets/paginator.gleam", 37).
-spec paginator_new(integer()) -> paginator().
-doc(~" New paginator. `total` is clamped to at least 1. Starts on page 0.").
paginator_new(Total) ->
    {paginator, 0, gleam@int:max(1, Total), 10, dots, ~"●", ~"○", default, default}.

-file("src/etui/widgets/paginator.gleam", 51).
-spec with_page_size(paginator(), integer()) -> paginator().
-doc(~" Items per page (used by `slice/2`). Default 10.").
with_page_size(P, N) ->
    {paginator, erlang:element(2, P), erlang:element(3, P), gleam@int:max(1, N), erlang:element(5, P), erlang:element(6, P), erlang:element(7, P), erlang:element(8, P), erlang:element(9, P)}.

-file("src/etui/widgets/paginator.gleam", 55).
-spec with_style(paginator(), paginator_style()) -> paginator().
with_style(P, St) ->
    {paginator, erlang:element(2, P), erlang:element(3, P), erlang:element(4, P), St, erlang:element(6, P), erlang:element(7, P), erlang:element(8, P), erlang:element(9, P)}.

-file("src/etui/widgets/paginator.gleam", 59).
-spec with_chars(paginator(), binary(), binary()) -> paginator().
with_chars(P, Active, Inactive) ->
    {paginator, erlang:element(2, P), erlang:element(3, P), erlang:element(4, P), erlang:element(5, P), Active, Inactive, erlang:element(8, P), erlang:element(9, P)}.

-file("src/etui/widgets/paginator.gleam", 63).
-spec with_colors(paginator(), etui@style:color(), etui@style:color()) -> paginator().
with_colors(P, Fg, Bg) ->
    {paginator, erlang:element(2, P), erlang:element(3, P), erlang:element(4, P), erlang:element(5, P), erlang:element(6, P), erlang:element(7, P), Fg, Bg}.

-file("src/etui/widgets/paginator.gleam", 75).
-spec next_page(paginator()) -> paginator().
-doc(~" Next page, clamped to last.").
next_page(P) ->
    {paginator, gleam@int:min(erlang:element(2, P) + 1, erlang:element(3, P) - 1), erlang:element(3, P), erlang:element(4, P), erlang:element(5, P), erlang:element(6, P), erlang:element(7, P), erlang:element(8, P), erlang:element(9, P)}.

-file("src/etui/widgets/paginator.gleam", 80).
-spec prev_page(paginator()) -> paginator().
-doc(~" Previous page, clamped to 0.").
prev_page(P) ->
    {paginator, gleam@int:max(erlang:element(2, P) - 1, 0), erlang:element(3, P), erlang:element(4, P), erlang:element(5, P), erlang:element(6, P), erlang:element(7, P), erlang:element(8, P), erlang:element(9, P)}.

-file("src/etui/widgets/paginator.gleam", 85).
-spec go_to(paginator(), integer()) -> paginator().
-doc(~" Jump to a specific page, clamped to `[0, total - 1]`.").
go_to(P, Page) ->
    {paginator, gleam@int:clamp(Page, 0, erlang:element(3, P) - 1), erlang:element(3, P), erlang:element(4, P), erlang:element(5, P), erlang:element(6, P), erlang:element(7, P), erlang:element(8, P), erlang:element(9, P)}.

-file("src/etui/widgets/paginator.gleam", 91).
-spec set_item_count(paginator(), integer()) -> paginator().
-doc(~" Recompute `total` from an item count and the current `page_size`.
 Clamps `current` so it stays in range.").
set_item_count(P, Items) ->
    N = gleam@int:max(0, Items),
    Total = gleam@int:max(1, case erlang:element(4, P) of
        0 ->
            0;

        _value ->
            ((N + erlang:element(4, P)) - 1) div _value
    end),
    Current = gleam@int:min(erlang:element(2, P), Total - 1),
    {paginator, Current, Total, erlang:element(4, P), erlang:element(5, P), erlang:element(6, P), erlang:element(7, P), erlang:element(8, P), erlang:element(9, P)}.

-file("src/etui/widgets/paginator.gleam", 102).
-spec slice(list(HDB), paginator()) -> list(HDB).
-doc(~" Pull the items belonging to the current page.").
slice(Items, P) ->
    _pipe = Items,
    _pipe@1 = gleam@list:drop(_pipe, erlang:element(2, P) * erlang:element(4, P)),
    gleam@list:take(_pipe@1, erlang:element(4, P)).

-file("src/etui/widgets/paginator.gleam", 135).
-spec dots_text(paginator()) -> binary().
dots_text(P) ->
    _pipe = gleam@list:repeat(nil, erlang:element(3, P)),
    _pipe@1 = gleam@list:index_map(_pipe, fun(_, I) ->
        case I =:= erlang:element(2, P) of
            true ->
                erlang:element(6, P);

            false ->
                erlang:element(7, P)
        end
    end),
    gleam@string:join(_pipe@1, ~" ").

-file("src/etui/widgets/paginator.gleam", 111).
-spec render(etui@buffer:buffer(), etui@geometry:rect(), paginator()) -> etui@buffer:buffer().
render(Buf, Area, P) ->
    case (erlang:element(2, erlang:element(3, Area)) =< 0) orelse (erlang:element(3, erlang:element(3, Area)) =< 0) of
        true ->
            Buf;

        false ->
            Txt = case erlang:element(5, P) of
                dots ->
                    dots_text(P);

                arabic ->
                    <<<<(erlang:integer_to_binary(erlang:element(2, P) + 1))/binary, "/"/utf8>>/binary, (erlang:integer_to_binary(erlang:element(3, P)))/binary>>
            end,
            Txt_w = etui@text:cell_width(Txt),
            X_off = gleam@int:max(0, (erlang:element(2, erlang:element(3, Area)) - Txt_w) div 2),
            etui@buffer:set_string(Buf, {position, erlang:element(2, erlang:element(2, Area)) + X_off, erlang:element(3, erlang:element(2, Area))}, etui@text:truncate(Txt, erlang:element(2, erlang:element(3, Area)), ~""), etui@style:new(erlang:element(8, P), erlang:element(9, P), etui@style:none()))
    end.

