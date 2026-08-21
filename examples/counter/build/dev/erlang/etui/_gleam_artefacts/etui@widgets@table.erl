-module(etui@widgets@table).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([table_new/1, with_col_widths/2, with_col_constraints/2, with_header/2, with_colors/3, with_highlight_style/2, with_style/2, with_blink/2, state_new/0, select_row/2, select_next_row/2, select_prev_row/1, clamp_state/2, effective_offset/2, settle/2, render/3, render_stateful/4, render_animated/5]).
-export_type([table_widget/0, table_state/0]).

-type table_widget() :: {table_widget, list(list(binary())), list(integer()), list(etui@geometry:constraint()), boolean(), etui@style:color(), etui@style:color(), etui@style:style(), integer()}.

-type table_state() :: {table_state, integer(), integer()}.

-file("src/etui/widgets/table.gleam", 51).
-spec table_new(list(list(binary()))) -> table_widget().
-doc(~" New table. Column widths default to 10 cells each.").
table_new(Rows) ->
    Col_widths = case Rows of
        [] ->
            [];

        [First | _] ->
            gleam@list:repeat(10, erlang:length(First))
    end,
    {table_widget, Rows, Col_widths, [], false, default, default, etui@style:new(default, default, etui@style:reverse()), 0}.

-file("src/etui/widgets/table.gleam", 69).
-spec with_col_widths(table_widget(), list(integer())) -> table_widget().
-doc(~" Override column widths (cell counts). Must match number of columns.").
with_col_widths(T, Widths) ->
    {table_widget, erlang:element(2, T), Widths, erlang:element(4, T), erlang:element(5, T), erlang:element(6, T), erlang:element(7, T), erlang:element(8, T), erlang:element(9, T)}.

-file("src/etui/widgets/table.gleam", 76).
-spec with_col_constraints(table_widget(), list(etui@geometry:constraint())) -> table_widget().
-doc(~" Constraint-based column widths, resolved from area width at render time.
 When set, takes precedence over `col_widths`.
 Separator cells (│) are subtracted before resolving.").
with_col_constraints(T, Constraints) ->
    {table_widget, erlang:element(2, T), erlang:element(3, T), Constraints, erlang:element(5, T), erlang:element(6, T), erlang:element(7, T), erlang:element(8, T), erlang:element(9, T)}.

-file("src/etui/widgets/table.gleam", 86).
-spec with_header(table_widget(), boolean()) -> table_widget().
-doc(~" When true, `t.rows[0]` is rendered as a bold header row (never selectable).
 `selected_row` uses absolute indices: 0 = header, 1 = first data row, etc.
 Initialize state with `select_row(state_new(), 1)` for the first data row.").
with_header(T, Show) ->
    {table_widget, erlang:element(2, T), erlang:element(3, T), erlang:element(4, T), Show, erlang:element(6, T), erlang:element(7, T), erlang:element(8, T), erlang:element(9, T)}.

-file("src/etui/widgets/table.gleam", 90).
-spec with_colors(table_widget(), etui@style:color(), etui@style:color()) -> table_widget().
with_colors(T, Fg, Bg) ->
    {table_widget, erlang:element(2, T), erlang:element(3, T), erlang:element(4, T), erlang:element(5, T), Fg, Bg, erlang:element(8, T), erlang:element(9, T)}.

-file("src/etui/widgets/table.gleam", 98).
-spec with_highlight_style(table_widget(), etui@style:style()) -> table_widget().
with_highlight_style(T, S) ->
    {table_widget, erlang:element(2, T), erlang:element(3, T), erlang:element(4, T), erlang:element(5, T), erlang:element(6, T), erlang:element(7, T), S, erlang:element(9, T)}.

-file("src/etui/widgets/table.gleam", 102).
-spec with_style(table_widget(), etui@style:style()) -> table_widget().
with_style(T, S) ->
    {table_widget, erlang:element(2, T), erlang:element(3, T), erlang:element(4, T), erlang:element(5, T), erlang:element(2, S), erlang:element(3, S), erlang:element(8, T), erlang:element(9, T)}.

-file("src/etui/widgets/table.gleam", 107).
-spec with_blink(table_widget(), integer()) -> table_widget().
-doc(~" Blink period in frames. 0 = steady (no blink). Use with `render_animated`.").
with_blink(T, Period) ->
    {table_widget, erlang:element(2, T), erlang:element(3, T), erlang:element(4, T), erlang:element(5, T), erlang:element(6, T), erlang:element(7, T), erlang:element(8, T), Period}.

-file("src/etui/widgets/table.gleam", 117).
-spec state_new() -> table_state().
-doc(~" Initial state: selected_row=0, no scroll offset.
 When using `with_header(True)`, row 0 is the header (not selectable).
 Use `select_row(state_new(), 1)` to start with the first data row highlighted.").
state_new() ->
    {table_state, 0, 0}.

-file("src/etui/widgets/table.gleam", 122).
-spec select_row(table_state(), integer()) -> table_state().
-doc(~" Jump to a specific row (clamped to ≥ 0).").
select_row(State, Idx) ->
    {table_state, gleam@int:max(0, Idx), erlang:element(3, State)}.

-file("src/etui/widgets/table.gleam", 127).
-spec select_next_row(table_state(), integer()) -> table_state().
-doc(~" Move selection down by one, clamped to last row.").
select_next_row(State, Row_count) ->
    Max_idx = gleam@int:max(0, Row_count - 1),
    {table_state, gleam@int:min(Max_idx, erlang:element(2, State) + 1), erlang:element(3, State)}.

-file("src/etui/widgets/table.gleam", 133).
-spec select_prev_row(table_state()) -> table_state().
-doc(~" Move selection up by one, clamped to 0.").
select_prev_row(State) ->
    {table_state, gleam@int:max(0, erlang:element(2, State) - 1), erlang:element(3, State)}.

-file("src/etui/widgets/table.gleam", 139).
-spec clamp_state(table_state(), integer()) -> table_state().
-doc(~" Clamp `selected_row` to `[0, row_count - 1]`.
 Call after replacing the row list to avoid a stale selection index.").
clamp_state(State, Row_count) ->
    Max = gleam@int:max(0, Row_count - 1),
    {table_state, gleam@int:min(erlang:element(2, State), Max), erlang:element(3, State)}.

-file("src/etui/widgets/table.gleam", 288).
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

-file("src/etui/widgets/table.gleam", 156).
-spec effective_offset(table_state(), integer()) -> integer().
effective_offset(State, Visible_data_h) ->
    scroll_offset(erlang:element(2, State), erlang:element(3, State), Visible_data_h).

-file("src/etui/widgets/table.gleam", 152).
-spec settle(table_state(), integer()) -> table_state().
-doc(~" Effective scroll offset for a viewport of `visible_data_h` data rows.
 When `show_header` is True, pass `area.size.height - 1`; otherwise pass `area.size.height`.
 Pass as `offset` to `scrollbar.scrollbar_new`.
 The state this table settles on once it knows how many data rows fit.

 Same reasoning as `list.settle`: pass the height of the data area, which is
 the area height less one row when a header is shown, and keep the result so
 the viewport holds still.").
settle(State, Visible_data_h) ->
    {table_state, erlang:element(2, State), effective_offset(State, Visible_data_h)}.

-file("src/etui/widgets/table.gleam", 357).
-spec render_empty_line(integer()) -> binary().
render_empty_line(Width) ->
    etui@text:pad_right(~"", Width).

-file("src/etui/widgets/table.gleam", 340).
-spec render_cells(list(binary()), list(integer())) -> list(binary()).
render_cells(Row, Widths) ->
    case {Row, Widths} of
        {_, []} ->
            [];

        {[], [Width | Rest_widths]} ->
            Formatted = etui@text:pad_right(~"", gleam@int:max(0, Width - 1)),
            [Formatted | render_cells([], Rest_widths)];

        {[Cell | Rest_row], [Width@1 | Rest_widths@1]} ->
            Formatted@1 = begin
                _pipe = etui@text:truncate(Cell, Width@1 - 1, ~""),
                etui@text:pad_right(_pipe, Width@1 - 1)
            end,
            [Formatted@1 | render_cells(Rest_row, Rest_widths@1)]
    end.

-file("src/etui/widgets/table.gleam", 318).
-spec render_row_line(list(binary()), list(integer()), integer(), boolean()) -> binary().
render_row_line(Row, Col_widths, Max_width, Is_selected) ->
    Cells = render_cells(Row, Col_widths),
    Line = gleam@list:fold(Cells, ~"", fun(Acc, Cell) ->
        case Acc of
            ~"" ->
                Cell;

            _ ->
                <<<<Acc/binary, "│"/utf8>>/binary, Cell/binary>>
        end
    end),
    Prefix = case Is_selected of
        true ->
            ~"▶";

        false ->
            ~" "
    end,
    _pipe = etui@text:truncate(<<Prefix/binary, Line/binary>>, Max_width, ~""),
    etui@text:pad_right(_pipe, Max_width).

-file("src/etui/widgets/table.gleam", 306).
-spec get_row_at(list(list(binary())), integer()) -> {ok, list(binary())} | {error, nil}.
get_row_at(Rows, Idx) ->
    case Idx of
        I when I < 0 ->
            {error, nil};

        0 ->
            case Rows of
                [H | _] ->
                    {ok, H};

                [] ->
                    {error, nil}
            end;

        _ ->
            get_row_at(gleam@list:drop(Rows, 1), Idx - 1)
    end.

-file("src/etui/widgets/table.gleam", 223).
-spec do_render(etui@buffer:buffer(), etui@geometry:rect(), table_widget(), integer(), integer(), integer()) -> etui@buffer:buffer().
do_render(Buf, Area, T, Selected, Offset, Y_offset) ->
    Col_widths = case erlang:element(4, T) of
        [] ->
            erlang:element(3, T);

        Constraints ->
            etui@geometry:resolve_sizes(erlang:element(2, erlang:element(3, Area)), Constraints)
    end,
    case Y_offset >= erlang:element(3, erlang:element(3, Area)) of
        true ->
            Buf;

        false ->
            Y = erlang:element(3, erlang:element(2, Area)) + Y_offset,
            Is_header = erlang:element(5, T) andalso (Y_offset =:= 0),
            Row_idx = Offset + Y_offset,
            Is_selected = not Is_header andalso (Row_idx =:= Selected),
            Row_line = case Is_header of
                true ->
                    case get_row_at(erlang:element(2, T), 0) of
                        {ok, Row} ->
                            render_row_line(Row, Col_widths, erlang:element(2, erlang:element(3, Area)), false);

                        {error, _} ->
                            render_empty_line(erlang:element(2, erlang:element(3, Area)))
                    end;

                false ->
                    case get_row_at(erlang:element(2, T), Row_idx) of
                        {ok, Row@1} ->
                            render_row_line(Row@1, Col_widths, erlang:element(2, erlang:element(3, Area)), Is_selected);

                        {error, _} ->
                            render_empty_line(erlang:element(2, erlang:element(3, Area)))
                    end
            end,
            {Row_fg, Row_bg, Row_modifier} = case Is_header of
                true ->
                    {erlang:element(6, T), erlang:element(7, T), etui@style:bold()};

                false ->
                    case Is_selected of
                        true ->
                            {erlang:element(2, erlang:element(8, T)), erlang:element(3, erlang:element(8, T)), erlang:element(4, erlang:element(8, T))};

                        false ->
                            {erlang:element(6, T), erlang:element(7, T), etui@style:none()}
                    end
            end,
            Buf_new = etui@buffer:set_string(Buf, {position, erlang:element(2, erlang:element(2, Area)), Y}, Row_line, etui@style:new(Row_fg, Row_bg, Row_modifier)),
            do_render(Buf_new, Area, T, Selected, Offset, Y_offset + 1)
    end.

-file("src/etui/widgets/table.gleam", 164).
-spec render(etui@buffer:buffer(), etui@geometry:rect(), table_widget()) -> etui@buffer:buffer().
-doc(~" Render without selection highlight.").
render(Buf, Area, T) ->
    case erlang:element(3, erlang:element(3, Area)) =< 0 of
        true ->
            Buf;

        false ->
            do_render(Buf, Area, T, -1, 0, 0)
    end.

-file("src/etui/widgets/table.gleam", 176).
-spec render_stateful(etui@buffer:buffer(), etui@geometry:rect(), table_widget(), table_state()) -> etui@buffer:buffer().
-doc(~" Render with selection and auto-scrolling from state.").
render_stateful(Buf, Area, T, State) ->
    case erlang:element(3, erlang:element(3, Area)) =< 0 of
        true ->
            Buf;

        false ->
            Visible_data = case erlang:element(5, T) of
                true ->
                    gleam@int:max(0, erlang:element(3, erlang:element(3, Area)) - 1);

                false ->
                    erlang:element(3, erlang:element(3, Area))
            end,
            Offset = scroll_offset(erlang:element(2, State), erlang:element(3, State), Visible_data),
            do_render(Buf, Area, T, erlang:element(2, State), Offset, 0)
    end.

-file("src/etui/widgets/table.gleam", 198).
-spec render_animated(etui@buffer:buffer(), etui@geometry:rect(), table_widget(), table_state(), integer()) -> etui@buffer:buffer().
-doc(~" Like `render_stateful` but supports blinking selection via `t.blink_period`.
 Pass the current `AnimState.frame`; use `with_blink(t, period)` to configure.").
render_animated(Buf, Area, T, State, Frame) ->
    case erlang:element(3, erlang:element(3, Area)) =< 0 of
        true ->
            Buf;

        false ->
            Visible_data = case erlang:element(5, T) of
                true ->
                    gleam@int:max(0, erlang:element(3, erlang:element(3, Area)) - 1);

                false ->
                    erlang:element(3, erlang:element(3, Area))
            end,
            Offset = scroll_offset(erlang:element(2, State), erlang:element(3, State), Visible_data),
            Show = etui@anim:blink(Frame, erlang:element(9, T)),
            Sel = case Show of
                true ->
                    erlang:element(2, State);

                false ->
                    -1
            end,
            do_render(Buf, Area, T, Sel, Offset, 0)
    end.

