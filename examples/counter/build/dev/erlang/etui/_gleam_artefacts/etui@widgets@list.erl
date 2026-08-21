-module(etui@widgets@list).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([list_new/1, list_new_styled/1, with_colors/3, with_highlight_style/2, with_style/2, with_blink/2, state_new/0, select/2, select_next/2, select_prev/1, clamp_state/2, render/3, render_stateful/4, render_animated/5, effective_offset/2, settle/2]).
-export_type([list_widget/0, list_state/0]).

-type list_widget() :: {list_widget, list(etui@span:line()), etui@style:color(), etui@style:color(), etui@style:style(), integer()}.

-type list_state() :: {list_state, integer(), integer()}.

-file("src/etui/widgets/list.gleam", 34).
-spec list_new(list(binary())) -> list_widget().
-doc(~" New list from plain strings. Default colors, reverse-video selection.").
list_new(Items) ->
    {list_widget, gleam@list:map(Items, fun etui@span:line_plain/1), default, default, etui@style:new(default, default, etui@style:reverse()), 0}.

-file("src/etui/widgets/list.gleam", 52).
-spec list_new_styled(list(etui@span:line())) -> list_widget().
-doc(~" New list from styled `span.Line` items.

 ```gleam
 list.list_new_styled([
   span.line_new([span.span_styled(\"ERROR\", style.bold_style()), span.span_plain(\" file\")]),
   span.line_plain(\"normal item\"),
 ])
 ```").
list_new_styled(Items) ->
    {list_widget, Items, default, default, etui@style:new(default, default, etui@style:reverse()), 0}.

-file("src/etui/widgets/list.gleam", 62).
-spec with_colors(list_widget(), etui@style:color(), etui@style:color()) -> list_widget().
with_colors(L, Fg, Bg) ->
    {list_widget, erlang:element(2, L), Fg, Bg, erlang:element(5, L), erlang:element(6, L)}.

-file("src/etui/widgets/list.gleam", 70).
-spec with_highlight_style(list_widget(), etui@style:style()) -> list_widget().
with_highlight_style(L, S) ->
    {list_widget, erlang:element(2, L), erlang:element(3, L), erlang:element(4, L), S, erlang:element(6, L)}.

-file("src/etui/widgets/list.gleam", 74).
-spec with_style(list_widget(), etui@style:style()) -> list_widget().
with_style(L, S) ->
    {list_widget, erlang:element(2, L), erlang:element(2, S), erlang:element(3, S), erlang:element(5, L), erlang:element(6, L)}.

-file("src/etui/widgets/list.gleam", 79).
-spec with_blink(list_widget(), integer()) -> list_widget().
-doc(~" Blink period in frames. 0 = steady (no blink). Use with `render_animated`.").
with_blink(L, Period) ->
    {list_widget, erlang:element(2, L), erlang:element(3, L), erlang:element(4, L), erlang:element(5, L), Period}.

-file("src/etui/widgets/list.gleam", 86).
-spec state_new() -> list_state().
state_new() ->
    {list_state, 0, 0}.

-file("src/etui/widgets/list.gleam", 90).
-spec select(list_state(), integer()) -> list_state().
select(State, Idx) ->
    {list_state, gleam@int:max(0, Idx), erlang:element(3, State)}.

-file("src/etui/widgets/list.gleam", 94).
-spec select_next(list_state(), integer()) -> list_state().
select_next(State, Item_count) ->
    Max_idx = gleam@int:max(0, Item_count - 1),
    {list_state, gleam@int:min(Max_idx, erlang:element(2, State) + 1), erlang:element(3, State)}.

-file("src/etui/widgets/list.gleam", 99).
-spec select_prev(list_state()) -> list_state().
select_prev(State) ->
    {list_state, gleam@int:max(0, erlang:element(2, State) - 1), erlang:element(3, State)}.

-file("src/etui/widgets/list.gleam", 105).
-spec clamp_state(list_state(), integer()) -> list_state().
-doc(~" Clamp `selected` to `[0, item_count - 1]`.
 Call after replacing the item list to avoid a stale selection index.").
clamp_state(State, Item_count) ->
    Max = gleam@int:max(0, Item_count - 1),
    {list_state, gleam@int:min(erlang:element(2, State), Max), erlang:element(3, State)}.

-file("src/etui/widgets/list.gleam", 227).
-spec apply_highlight_to_line(etui@span:line(), etui@style:style()) -> etui@span:line().
apply_highlight_to_line(Line, Hl) ->
    etui@span:line_new(gleam@list:map(erlang:element(2, Line), fun(Sp) ->
        New_fg = case erlang:element(2, erlang:element(3, Sp)) of
            default ->
                erlang:element(2, Hl);

            _ ->
                erlang:element(2, erlang:element(3, Sp))
        end,
        New_bg = case erlang:element(3, erlang:element(3, Sp)) of
            default ->
                erlang:element(3, Hl);

            _ ->
                erlang:element(3, erlang:element(3, Sp))
        end,
        New_mod = case etui@style:modifier_equal(erlang:element(4, erlang:element(3, Sp)), etui@style:none()) of
            true ->
                erlang:element(4, Hl);

            false ->
                erlang:element(4, erlang:element(3, Sp))
        end,
        {span, erlang:element(2, Sp), etui@style:new(New_fg, New_bg, New_mod), erlang:element(4, Sp)}
    end)).

-file("src/etui/widgets/list.gleam", 293).
-spec get_item_at(list(etui@span:line()), integer()) -> {ok, etui@span:line()} | {error, nil}.
get_item_at(Items, Idx) ->
    case Idx of
        I when I < 0 ->
            {error, nil};

        0 ->
            case Items of
                [H | _] ->
                    {ok, H};

                [] ->
                    {error, nil}
            end;

        _ ->
            get_item_at(gleam@list:drop(Items, 1), Idx - 1)
    end.

-file("src/etui/widgets/list.gleam", 160).
-spec do_render(etui@buffer:buffer(), etui@geometry:rect(), list_widget(), integer(), integer(), integer()) -> etui@buffer:buffer().
do_render(Buf, Area, L, Selected, Offset, Y_offset) ->
    case Y_offset >= erlang:element(3, erlang:element(3, Area)) of
        true ->
            Buf;

        false ->
            Item_idx = Offset + Y_offset,
            Y = erlang:element(3, erlang:element(2, Area)) + Y_offset,
            Is_selected = Item_idx =:= Selected,
            {Row_fg, Row_bg, Row_mod} = case Is_selected of
                true ->
                    {erlang:element(2, erlang:element(5, L)), erlang:element(3, erlang:element(5, L)), erlang:element(4, erlang:element(5, L))};

                false ->
                    {erlang:element(3, L), erlang:element(4, L), etui@style:none()}
            end,
            Bg_row = etui@text:pad_right(~"", erlang:element(2, erlang:element(3, Area))),
            Buf1 = etui@buffer:set_string(Buf, {position, erlang:element(2, erlang:element(2, Area)), Y}, Bg_row, etui@style:new(Row_fg, Row_bg, Row_mod)),
            Buf2 = case get_item_at(erlang:element(2, L), Item_idx) of
                {error, _} ->
                    Buf1;

                {ok, Line} ->
                    Prefix = case Is_selected of
                        true ->
                            ~"▶ ";

                        false ->
                            ~"  "
                    end,
                    Prefix_w = etui@text:cell_width(Prefix),
                    Buf3 = etui@buffer:set_string(Buf1, {position, erlang:element(2, erlang:element(2, Area)), Y}, Prefix, etui@style:new(Row_fg, Row_bg, Row_mod)),
                    Effective_line = case Is_selected of
                        false ->
                            Line;

                        true ->
                            apply_highlight_to_line(Line, erlang:element(5, L))
                    end,
                    etui@span:render_line(Buf3, {position, erlang:element(2, erlang:element(2, Area)) + Prefix_w, Y}, Effective_line, erlang:element(2, erlang:element(3, Area)) - Prefix_w)
            end,
            do_render(Buf2, Area, L, Selected, Offset, Y_offset + 1)
    end.

-file("src/etui/widgets/list.gleam", 113).
-spec render(etui@buffer:buffer(), etui@geometry:rect(), list_widget()) -> etui@buffer:buffer().
render(Buf, Area, L) ->
    case erlang:element(3, erlang:element(3, Area)) =< 0 of
        true ->
            Buf;

        false ->
            do_render(Buf, Area, L, -1, 0, 0)
    end.

-file("src/etui/widgets/list.gleam", 275).
-spec scroll_offset(integer(), integer(), integer()) -> integer().
scroll_offset(Selected, Offset, Height) ->
    case Selected < Offset of
        true ->
            Selected;

        false ->
            case Height =< 0 of
                true ->
                    Offset;

                false ->
                    case Selected >= (Offset + Height) of
                        true ->
                            (Selected - Height) + 1;

                        false ->
                            Offset
                    end
            end
    end.

-file("src/etui/widgets/list.gleam", 124).
-spec render_stateful(etui@buffer:buffer(), etui@geometry:rect(), list_widget(), list_state()) -> etui@buffer:buffer().
render_stateful(Buf, Area, L, State) ->
    case erlang:element(3, erlang:element(3, Area)) =< 0 of
        true ->
            Buf;

        false ->
            Offset = scroll_offset(erlang:element(2, State), erlang:element(3, State), erlang:element(3, erlang:element(3, Area))),
            do_render(Buf, Area, L, erlang:element(2, State), Offset, 0)
    end.

-file("src/etui/widgets/list.gleam", 139).
-spec render_animated(etui@buffer:buffer(), etui@geometry:rect(), list_widget(), list_state(), integer()) -> etui@buffer:buffer().
render_animated(Buf, Area, L, State, Frame) ->
    case erlang:element(3, erlang:element(3, Area)) =< 0 of
        true ->
            Buf;

        false ->
            Offset = scroll_offset(erlang:element(2, State), erlang:element(3, State), erlang:element(3, erlang:element(3, Area))),
            Show = etui@anim:blink(Frame, erlang:element(6, L)),
            Sel = case Show of
                true ->
                    erlang:element(2, State);

                false ->
                    -1
            end,
            do_render(Buf, Area, L, Sel, Offset, 0)
    end.

-file("src/etui/widgets/list.gleam", 250).
-spec effective_offset(list_state(), integer()) -> integer().
effective_offset(State, Height) ->
    scroll_offset(erlang:element(2, State), erlang:element(3, State), Height).

-file("src/etui/widgets/list.gleam", 271).
-spec settle(list_state(), integer()) -> list_state().
-doc(~" The state this list settles on once it knows it has `height` rows.

 A list cannot work out its scroll offset until it knows how tall its area
 is, and that is decided by the layout, not by the model. Call this with the
 height you are about to render into and keep the result:

 ```gleam
 let inner = block.inner(area, blk)
 let listed = list.settle(model.list, inner.size.height)
 let buf = list.render_stateful(buf, inner, widget, listed)
 // store `listed` back in the model
 ```

 Rendering without doing this still draws the right rows, because
 `render_stateful` works the offset out for itself. What it costs is that
 the offset never persists, so the viewport slides one row with every step
 instead of holding still until the selection leaves it.").
settle(State, Height) ->
    {list_state, erlang:element(2, State), effective_offset(State, Height)}.

