-module(etui@widgets@multi_select).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([multi_select_new/1, with_max/2, with_marks/3, with_cursor_mark/2, with_cursor_style/2, with_selected_style/2, with_colors/3, state_new/0, select_next/2, select_prev/1, toggle/2, is_selected/2, selected_indices/1, selected_values/2, clear_selection/1, effective_offset/2, render/4]).
-export_type([multi_select_widget/0, multi_select_state/0]).

-type multi_select_widget() :: {multi_select_widget, list(binary()), etui@style:style(), etui@style:style(), binary(), binary(), binary(), integer(), etui@style:color(), etui@style:color()}.

-type multi_select_state() :: {multi_select_state, integer(), list(integer()), integer()}.

-file("src/etui/widgets/multi_select.gleam", 37).
-spec multi_select_new(list(binary())) -> multi_select_widget().
multi_select_new(Items) ->
    {multi_select_widget, Items, etui@style:new(default, default, etui@style:reverse()), etui@style:new(default, default, etui@style:bold()), ~"[x] ", ~"[ ] ", ~"▶ ", 0, default, default}.

-file("src/etui/widgets/multi_select.gleam", 52).
-spec with_max(multi_select_widget(), integer()) -> multi_select_widget().
-doc(~" Cap the number of selected items. 0 = unlimited.").
with_max(W, M) ->
    {multi_select_widget, erlang:element(2, W), erlang:element(3, W), erlang:element(4, W), erlang:element(5, W), erlang:element(6, W), erlang:element(7, W), gleam@int:max(0, M), erlang:element(9, W), erlang:element(10, W)}.

-file("src/etui/widgets/multi_select.gleam", 56).
-spec with_marks(multi_select_widget(), binary(), binary()) -> multi_select_widget().
with_marks(W, Checked, Unchecked) ->
    {multi_select_widget, erlang:element(2, W), erlang:element(3, W), erlang:element(4, W), Checked, Unchecked, erlang:element(7, W), erlang:element(8, W), erlang:element(9, W), erlang:element(10, W)}.

-file("src/etui/widgets/multi_select.gleam", 64).
-spec with_cursor_mark(multi_select_widget(), binary()) -> multi_select_widget().
with_cursor_mark(W, M) ->
    {multi_select_widget, erlang:element(2, W), erlang:element(3, W), erlang:element(4, W), erlang:element(5, W), erlang:element(6, W), M, erlang:element(8, W), erlang:element(9, W), erlang:element(10, W)}.

-file("src/etui/widgets/multi_select.gleam", 68).
-spec with_cursor_style(multi_select_widget(), etui@style:style()) -> multi_select_widget().
with_cursor_style(W, S) ->
    {multi_select_widget, erlang:element(2, W), S, erlang:element(4, W), erlang:element(5, W), erlang:element(6, W), erlang:element(7, W), erlang:element(8, W), erlang:element(9, W), erlang:element(10, W)}.

-file("src/etui/widgets/multi_select.gleam", 75).
-spec with_selected_style(multi_select_widget(), etui@style:style()) -> multi_select_widget().
with_selected_style(W, S) ->
    {multi_select_widget, erlang:element(2, W), erlang:element(3, W), S, erlang:element(5, W), erlang:element(6, W), erlang:element(7, W), erlang:element(8, W), erlang:element(9, W), erlang:element(10, W)}.

-file("src/etui/widgets/multi_select.gleam", 82).
-spec with_colors(multi_select_widget(), etui@style:color(), etui@style:color()) -> multi_select_widget().
with_colors(W, Fg, Bg) ->
    {multi_select_widget, erlang:element(2, W), erlang:element(3, W), erlang:element(4, W), erlang:element(5, W), erlang:element(6, W), erlang:element(7, W), erlang:element(8, W), Fg, Bg}.

-file("src/etui/widgets/multi_select.gleam", 93).
-spec state_new() -> multi_select_state().
state_new() ->
    {multi_select_state, 0, [], 0}.

-file("src/etui/widgets/multi_select.gleam", 97).
-spec select_next(multi_select_state(), integer()) -> multi_select_state().
select_next(State, Item_count) ->
    Max_idx = gleam@int:max(0, Item_count - 1),
    {multi_select_state, gleam@int:min(erlang:element(2, State) + 1, Max_idx), erlang:element(3, State), erlang:element(4, State)}.

-file("src/etui/widgets/multi_select.gleam", 105).
-spec select_prev(multi_select_state()) -> multi_select_state().
select_prev(State) ->
    {multi_select_state, gleam@int:max(erlang:element(2, State) - 1, 0), erlang:element(3, State), erlang:element(4, State)}.

-file("src/etui/widgets/multi_select.gleam", 253).
-spec insert_sorted(list(integer()), integer()) -> list(integer()).
insert_sorted(Lst, N) ->
    case Lst of
        [] ->
            [N];

        [H | _] when N < H ->
            [N | Lst];

        [H@1 | _] when N =:= H@1 ->
            Lst;

        [H@2 | T] ->
            [H@2 | insert_sorted(T, N)]
    end.

-file("src/etui/widgets/multi_select.gleam", 110).
-spec toggle(multi_select_state(), integer()) -> multi_select_state().
-doc(~" Toggle the cursor item. Respects `max` from the widget config.").
toggle(State, Max) ->
    case gleam@list:contains(erlang:element(3, State), erlang:element(2, State)) of
        true ->
            {multi_select_state, erlang:element(2, State), gleam@list:filter(erlang:element(3, State), fun(I) ->
                I /= erlang:element(2, State)
            end), erlang:element(4, State)};

        false ->
            case (Max > 0) andalso (erlang:length(erlang:element(3, State)) >= Max) of
                true ->
                    State;

                false ->
                    {multi_select_state, erlang:element(2, State), insert_sorted(erlang:element(3, State), erlang:element(2, State)), erlang:element(4, State)}
            end
    end.

-file("src/etui/widgets/multi_select.gleam", 129).
-spec is_selected(multi_select_state(), integer()) -> boolean().
is_selected(State, Idx) ->
    gleam@list:contains(erlang:element(3, State), Idx).

-file("src/etui/widgets/multi_select.gleam", 133).
-spec selected_indices(multi_select_state()) -> list(integer()).
selected_indices(State) ->
    erlang:element(3, State).

-file("src/etui/widgets/multi_select.gleam", 138).
-spec selected_values(list(binary()), multi_select_state()) -> list(binary()).
-doc(~" Pull the selected item strings in original order.").
selected_values(Items, State) ->
    _pipe = Items,
    _pipe@1 = gleam@list:index_map(_pipe, fun(Item, I) ->
        {I, Item}
    end),
    gleam@list:filter_map(_pipe@1, fun(Pair) ->
        case gleam@list:contains(erlang:element(3, State), erlang:element(1, Pair)) of
            true ->
                {ok, erlang:element(2, Pair)};

            false ->
                {error, nil}
        end
    end).

-file("src/etui/widgets/multi_select.gleam", 152).
-spec clear_selection(multi_select_state()) -> multi_select_state().
clear_selection(State) ->
    {multi_select_state, erlang:element(2, State), [], erlang:element(4, State)}.

-file("src/etui/widgets/multi_select.gleam", 238).
-spec scroll_offset(integer(), integer(), integer()) -> integer().
scroll_offset(Cursor, Offset, Height) ->
    case Cursor < Offset of
        true ->
            Cursor;

        false ->
            case Height =< 0 of
                true ->
                    Offset;

                false ->
                    case Cursor >= (Offset + Height) of
                        true ->
                            (Cursor - Height) + 1;

                        false ->
                            Offset
                    end
            end
    end.

-file("src/etui/widgets/multi_select.gleam", 157).
-spec effective_offset(multi_select_state(), integer()) -> integer().
-doc(~" Effective scroll offset for a viewport of `height` rows.").
effective_offset(State, Height) ->
    scroll_offset(erlang:element(2, State), erlang:element(4, State), Height).

-file("src/etui/widgets/multi_select.gleam", 179).
-spec render_rows(etui@buffer:buffer(), etui@geometry:rect(), multi_select_widget(), multi_select_state(), integer(), integer()) -> etui@buffer:buffer().
render_rows(Buf, Area, W, State, Offset, Row_off) ->
    case Row_off >= erlang:element(3, erlang:element(3, Area)) of
        true ->
            Buf;

        false ->
            Item_idx = Offset + Row_off,
            case gleam@list:drop(erlang:element(2, W), Item_idx) of
                [] ->
                    Buf;

                [Item | _] ->
                    Y = erlang:element(3, erlang:element(2, Area)) + Row_off,
                    Is_cursor = Item_idx =:= erlang:element(2, State),
                    Is_sel = gleam@list:contains(erlang:element(3, State), Item_idx),
                    Prefix = case Is_cursor of
                        true ->
                            erlang:element(7, W);

                        false ->
                            gleam@string:repeat(~" ", etui@text:cell_width(erlang:element(7, W)))
                    end,
                    Mark = case Is_sel of
                        true ->
                            erlang:element(5, W);

                        false ->
                            erlang:element(6, W)
                    end,
                    Raw = <<<<Prefix/binary, Mark/binary>>/binary, Item/binary>>,
                    Truncated = etui@text:truncate(Raw, erlang:element(2, erlang:element(3, Area)), ~""),
                    Padded = etui@text:pad_right(Truncated, erlang:element(2, erlang:element(3, Area))),
                    {Fg, Bg, Modifier} = case {Is_cursor, Is_sel} of
                        {true, _} ->
                            {erlang:element(2, erlang:element(3, W)), erlang:element(3, erlang:element(3, W)), erlang:element(4, erlang:element(3, W))};

                        {false, true} ->
                            {erlang:element(2, erlang:element(4, W)), erlang:element(3, erlang:element(4, W)), erlang:element(4, erlang:element(4, W))};

                        {false, false} ->
                            {erlang:element(9, W), erlang:element(10, W), etui@style:none()}
                    end,
                    Buf2 = etui@buffer:set_string(Buf, {position, erlang:element(2, erlang:element(2, Area)), Y}, Padded, etui@style:new(Fg, Bg, Modifier)),
                    render_rows(Buf2, Area, W, State, Offset, Row_off + 1)
            end
    end.

-file("src/etui/widgets/multi_select.gleam", 164).
-spec render(etui@buffer:buffer(), etui@geometry:rect(), multi_select_widget(), multi_select_state()) -> etui@buffer:buffer().
render(Buf, Area, W, State) ->
    case (erlang:element(3, erlang:element(3, Area)) =< 0) orelse (erlang:element(2, erlang:element(3, Area)) =< 0) of
        true ->
            Buf;

        false ->
            Offset = scroll_offset(erlang:element(2, State), erlang:element(4, State), erlang:element(3, erlang:element(3, Area))),
            render_rows(Buf, Area, W, State, Offset, 0)
    end.

