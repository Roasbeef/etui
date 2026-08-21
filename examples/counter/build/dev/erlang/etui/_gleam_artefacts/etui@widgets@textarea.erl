-module(etui@widgets@textarea).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([textarea_new/0, with_max_lines/2, with_max_line_length/2, with_colors/3, with_style/2, with_cursor_style/2, state_new/0, state_from_string/1, value/1, line_count/1, effective_offset/2, cursor_screen_pos/2, insert_char/3, backspace/1, newline/2, move_cursor_left/1, move_cursor_right/1, move_cursor_up/1, move_cursor_down/1, move_to_line_start/1, move_to_line_end/1, delete_to_line_end/1, render/4]).
-export_type([text_area/0, text_area_state/0]).

-type text_area() :: {text_area, integer(), integer(), etui@style:color(), etui@style:color(), etui@style:style()}.

-type text_area_state() :: {text_area_state, list(binary()), integer(), integer()}.

-file("src/etui/widgets/textarea.gleam", 72).
-spec textarea_new() -> text_area().
-doc(~" New textarea with default styles and no limits.").
textarea_new() ->
    {text_area, 0, 0, default, default, etui@style:new(default, default, etui@style:reverse())}.

-file("src/etui/widgets/textarea.gleam", 82).
-spec with_max_lines(text_area(), integer()) -> text_area().
with_max_lines(W, N) ->
    {text_area, N, erlang:element(3, W), erlang:element(4, W), erlang:element(5, W), erlang:element(6, W)}.

-file("src/etui/widgets/textarea.gleam", 86).
-spec with_max_line_length(text_area(), integer()) -> text_area().
with_max_line_length(W, N) ->
    {text_area, erlang:element(2, W), N, erlang:element(4, W), erlang:element(5, W), erlang:element(6, W)}.

-file("src/etui/widgets/textarea.gleam", 90).
-spec with_colors(text_area(), etui@style:color(), etui@style:color()) -> text_area().
with_colors(W, Fg, Bg) ->
    {text_area, erlang:element(2, W), erlang:element(3, W), Fg, Bg, erlang:element(6, W)}.

-file("src/etui/widgets/textarea.gleam", 94).
-spec with_style(text_area(), etui@style:style()) -> text_area().
with_style(W, S) ->
    {text_area, erlang:element(2, W), erlang:element(3, W), erlang:element(2, S), erlang:element(3, S), erlang:element(6, W)}.

-file("src/etui/widgets/textarea.gleam", 98).
-spec with_cursor_style(text_area(), etui@style:style()) -> text_area().
with_cursor_style(W, S) ->
    {text_area, erlang:element(2, W), erlang:element(3, W), erlang:element(4, W), erlang:element(5, W), S}.

-file("src/etui/widgets/textarea.gleam", 106).
-spec state_new() -> text_area_state().
-doc(~" Empty state: one empty line, cursor at top-left.").
state_new() ->
    {text_area_state, [~""], 0, 0}.

-file("src/etui/widgets/textarea.gleam", 111).
-spec state_from_string(binary()) -> text_area_state().
-doc(~" State pre-populated from a string (splits on `\\n`).").
state_from_string(S) ->
    Lines = gleam@string:split(S, ~"\n"),
    Row = erlang:length(Lines) - 1,
    Last_line = case gleam@list:last(Lines) of
        {ok, L} ->
            L;

        {error, _} ->
            ~""
    end,
    {text_area_state, Lines, etui@text:cell_width(Last_line), gleam@int:max(0, Row)}.

-file("src/etui/widgets/textarea.gleam", 129).
-spec value(text_area_state()) -> binary().
-doc(~" All lines joined with `\"\\n\"`.").
value(State) ->
    gleam@string:join(erlang:element(2, State), ~"\n").

-file("src/etui/widgets/textarea.gleam", 134).
-spec line_count(text_area_state()) -> integer().
-doc(~" Number of lines.").
line_count(State) ->
    erlang:length(erlang:element(2, State)).

-file("src/etui/widgets/textarea.gleam", 474).
-spec scroll_offset(integer(), integer()) -> integer().
scroll_offset(Cursor_y, Visible_h) ->
    case Visible_h =< 0 of
        true ->
            0;

        false ->
            case Cursor_y < Visible_h of
                true ->
                    0;

                false ->
                    (Cursor_y - Visible_h) + 1
            end
    end.

-file("src/etui/widgets/textarea.gleam", 141).
-spec effective_offset(text_area_state(), integer()) -> integer().
-doc(~" Effective scroll offset for a viewport of `visible_h` rows.
 Returns the index of the first visible line so the cursor stays in view.
 Pass as `offset` to `scrollbar.scrollbar_new`.").
effective_offset(State, Visible_h) ->
    scroll_offset(erlang:element(4, State), Visible_h).

-file("src/etui/widgets/textarea.gleam", 148).
-spec cursor_screen_pos(text_area_state(), etui@geometry:rect()) -> {ok, etui@geometry:position()} | {error, nil}.
-doc(~" Screen position of the hardware cursor within `area`.
 Returns `Error(Nil)` when the cursor column is beyond the area width
 (mirrors the render rule: no cursor cell is drawn off-screen).").
cursor_screen_pos(State, Area) ->
    case erlang:element(3, State) >= erlang:element(2, erlang:element(3, Area)) of
        true ->
            {error, nil};

        false ->
            Scroll = scroll_offset(erlang:element(4, State), erlang:element(3, erlang:element(3, Area))),
            {ok, {position, erlang:element(2, erlang:element(2, Area)) + erlang:element(3, State), (erlang:element(3, erlang:element(2, Area)) + erlang:element(4, State)) - Scroll}}
    end.

-file("src/etui/widgets/textarea.gleam", 429).
-spec set_line(list(binary()), integer(), binary()) -> list(binary()).
set_line(Lines, Idx, New_val) ->
    gleam@list:index_map(Lines, fun(Line, I) ->
        case I =:= Idx of
            true ->
                New_val;

            false ->
                Line
        end
    end).

-file("src/etui/widgets/textarea.gleam", 418).
-spec get_line(list(binary()), integer()) -> binary().
get_line(Lines, Idx) ->
    case Idx < 0 of
        true ->
            ~"";

        false ->
            case gleam@list:drop(Lines, Idx) of
                [H | _] ->
                    H;

                [] ->
                    ~""
            end
    end.

-file("src/etui/widgets/textarea.gleam", 168).
-spec insert_char(text_area(), text_area_state(), binary()) -> text_area_state().
-doc(~" Insert a character at the current cursor position.").
insert_char(W, State, Ch) ->
    Line = get_line(erlang:element(2, State), erlang:element(4, State)),
    Line_cells = etui@text:cell_width(Line),
    case (erlang:element(3, W) > 0) andalso (Line_cells >= erlang:element(3, W)) of
        true ->
            State;

        false ->
            Before = etui@text:truncate(Line, erlang:element(3, State), ~""),
            After = gleam@string:drop_start(Line, string:length(Before)),
            New_line = <<<<Before/binary, Ch/binary>>/binary, After/binary>>,
            {text_area_state, set_line(erlang:element(2, State), erlang:element(4, State), New_line), erlang:element(3, State) + etui@text:cell_width(Ch), erlang:element(4, State)}
    end.

-file("src/etui/widgets/textarea.gleam", 438).
-spec delete_line(list(binary()), integer()) -> list(binary()).
delete_line(Lines, Idx) ->
    gleam@list:index_fold(Lines, [], fun(Acc, Line, I) ->
        case I =:= Idx of
            true ->
                Acc;

            false ->
                lists:append(Acc, [Line])
        end
    end).

-file("src/etui/widgets/textarea.gleam", 192).
-spec backspace(text_area_state()) -> text_area_state().
-doc(~" Delete the character immediately before the cursor.
 If at column 0, merges the current line with the previous line.").
backspace(State) ->
    case erlang:element(3, State) > 0 of
        true ->
            Line = get_line(erlang:element(2, State), erlang:element(4, State)),
            Before = etui@text:truncate(Line, erlang:element(3, State) - 1, ~""),
            Graphemes_before = string:length(etui@text:truncate(Line, erlang:element(3, State), ~"")),
            After = gleam@string:drop_start(Line, Graphemes_before),
            {text_area_state, set_line(erlang:element(2, State), erlang:element(4, State), <<Before/binary, After/binary>>), etui@text:cell_width(Before), erlang:element(4, State)};

        false ->
            case erlang:element(4, State) > 0 of
                false ->
                    State;

                true ->
                    Prev = get_line(erlang:element(2, State), erlang:element(4, State) - 1),
                    Curr = get_line(erlang:element(2, State), erlang:element(4, State)),
                    Merged = <<Prev/binary, Curr/binary>>,
                    New_x = etui@text:cell_width(Prev),
                    New_lines = begin
                        _pipe = delete_line(erlang:element(2, State), erlang:element(4, State)),
                        set_line(_pipe, erlang:element(4, State) - 1, Merged)
                    end,
                    {text_area_state, New_lines, New_x, erlang:element(4, State) - 1}
            end
    end.

-file("src/etui/widgets/textarea.gleam", 455).
-spec insert_line_after_loop(list(binary()), integer(), binary(), integer(), list(binary())) -> list(binary()).
insert_line_after_loop(Lines, Idx, New_line, I, Acc) ->
    case Lines of
        [] ->
            lists:reverse(Acc);

        [H | Rest] ->
            Acc2 = case I =:= Idx of
                true ->
                    [New_line, H | Acc];

                false ->
                    [H | Acc]
            end,
            insert_line_after_loop(Rest, Idx, New_line, I + 1, Acc2)
    end.

-file("src/etui/widgets/textarea.gleam", 447).
-spec insert_line_after(list(binary()), integer(), binary()) -> list(binary()).
insert_line_after(Lines, Idx, New_line) ->
    insert_line_after_loop(Lines, Idx, New_line, 0, []).

-file("src/etui/widgets/textarea.gleam", 228).
-spec newline(text_area(), text_area_state()) -> text_area_state().
-doc(~" Insert a newline at the cursor. Splits the current line.").
newline(W, State) ->
    N_lines = erlang:length(erlang:element(2, State)),
    case (erlang:element(2, W) > 0) andalso (N_lines >= erlang:element(2, W)) of
        true ->
            State;

        false ->
            Line = get_line(erlang:element(2, State), erlang:element(4, State)),
            Before = etui@text:truncate(Line, erlang:element(3, State), ~""),
            After = gleam@string:drop_start(Line, string:length(Before)),
            New_lines = begin
                _pipe = set_line(erlang:element(2, State), erlang:element(4, State), Before),
                insert_line_after(_pipe, erlang:element(4, State), After)
            end,
            {text_area_state, New_lines, 0, erlang:element(4, State) + 1}
    end.

-file("src/etui/widgets/textarea.gleam", 248).
-spec move_cursor_left(text_area_state()) -> text_area_state().
-doc(~" Move cursor one cell left. Wraps to end of previous line.").
move_cursor_left(State) ->
    case erlang:element(3, State) > 0 of
        true ->
            Line = get_line(erlang:element(2, State), erlang:element(4, State)),
            New_x = etui@text:cell_width(etui@text:truncate(Line, erlang:element(3, State) - 1, ~"")),
            {text_area_state, erlang:element(2, State), New_x, erlang:element(4, State)};

        false ->
            case erlang:element(4, State) > 0 of
                false ->
                    State;

                true ->
                    Prev = get_line(erlang:element(2, State), erlang:element(4, State) - 1),
                    {text_area_state, erlang:element(2, State), etui@text:cell_width(Prev), erlang:element(4, State) - 1}
            end
    end.

-file("src/etui/widgets/textarea.gleam", 492).
-spec grapheme_width_at(binary(), integer()) -> integer().
grapheme_width_at(S, Cell_pos) ->
    Prefix = etui@text:truncate(S, Cell_pos, ~""),
    Rest = gleam@string:drop_start(S, string:length(Prefix)),
    case gleam@string:to_graphemes(Rest) of
        [G | _] ->
            etui@text:cell_width(G);

        [] ->
            1
    end.

-file("src/etui/widgets/textarea.gleam", 271).
-spec move_cursor_right(text_area_state()) -> text_area_state().
-doc(~" Move cursor one cell right. Wraps to start of next line.").
move_cursor_right(State) ->
    Line = get_line(erlang:element(2, State), erlang:element(4, State)),
    case erlang:element(3, State) < etui@text:cell_width(Line) of
        true ->
            Step = grapheme_width_at(Line, erlang:element(3, State)),
            {text_area_state, erlang:element(2, State), erlang:element(3, State) + Step, erlang:element(4, State)};

        false ->
            N_lines = erlang:length(erlang:element(2, State)),
            case erlang:element(4, State) < (N_lines - 1) of
                false ->
                    State;

                true ->
                    {text_area_state, erlang:element(2, State), 0, erlang:element(4, State) + 1}
            end
    end.

-file("src/etui/widgets/textarea.gleam", 487).
-spec snap_to_boundary(binary(), integer()) -> integer().
snap_to_boundary(S, Cell_pos) ->
    Clamped = gleam@int:min(Cell_pos, etui@text:cell_width(S)),
    etui@text:cell_width(etui@text:truncate(S, Clamped, ~"")).

-file("src/etui/widgets/textarea.gleam", 290).
-spec move_cursor_up(text_area_state()) -> text_area_state().
-doc(~" Move cursor up one line, clamping x to the new line's width.").
move_cursor_up(State) ->
    case erlang:element(4, State) > 0 of
        false ->
            State;

        true ->
            New_y = erlang:element(4, State) - 1,
            Prev = get_line(erlang:element(2, State), New_y),
            {text_area_state, erlang:element(2, State), snap_to_boundary(Prev, erlang:element(3, State)), New_y}
    end.

-file("src/etui/widgets/textarea.gleam", 306).
-spec move_cursor_down(text_area_state()) -> text_area_state().
-doc(~" Move cursor down one line, clamping x to the new line's width.").
move_cursor_down(State) ->
    N_lines = erlang:length(erlang:element(2, State)),
    case erlang:element(4, State) < (N_lines - 1) of
        false ->
            State;

        true ->
            New_y = erlang:element(4, State) + 1,
            Next = get_line(erlang:element(2, State), New_y),
            {text_area_state, erlang:element(2, State), snap_to_boundary(Next, erlang:element(3, State)), New_y}
    end.

-file("src/etui/widgets/textarea.gleam", 323).
-spec move_to_line_start(text_area_state()) -> text_area_state().
-doc(~" Move cursor to beginning of current line.").
move_to_line_start(State) ->
    {text_area_state, erlang:element(2, State), 0, erlang:element(4, State)}.

-file("src/etui/widgets/textarea.gleam", 328).
-spec move_to_line_end(text_area_state()) -> text_area_state().
-doc(~" Move cursor to end of current line.").
move_to_line_end(State) ->
    Line = get_line(erlang:element(2, State), erlang:element(4, State)),
    {text_area_state, erlang:element(2, State), etui@text:cell_width(Line), erlang:element(4, State)}.

-file("src/etui/widgets/textarea.gleam", 334).
-spec delete_to_line_end(text_area_state()) -> text_area_state().
-doc(~" Delete from cursor to end of current line.").
delete_to_line_end(State) ->
    Line = get_line(erlang:element(2, State), erlang:element(4, State)),
    Before = etui@text:truncate(Line, erlang:element(3, State), ~""),
    {text_area_state, set_line(erlang:element(2, State), erlang:element(4, State), Before), erlang:element(3, State), erlang:element(4, State)}.

-file("src/etui/widgets/textarea.gleam", 501).
-spec grapheme_at_cell(binary(), integer()) -> binary().
grapheme_at_cell(S, Cell_pos) ->
    Prefix = etui@text:truncate(S, Cell_pos, ~""),
    Rest = gleam@string:drop_start(S, string:length(Prefix)),
    case gleam@string:to_graphemes(Rest) of
        [G | _] ->
            G;

        [] ->
            ~" "
    end.

-file("src/etui/widgets/textarea.gleam", 382).
-spec render_line(etui@buffer:buffer(), etui@geometry:rect(), text_area(), text_area_state(), binary(), integer(), boolean()) -> etui@buffer:buffer().
render_line(Buf, Area, W, State, Line, Y, Is_cursor_row) ->
    Width = erlang:element(2, erlang:element(3, Area)),
    Truncated = etui@text:truncate(Line, Width, ~""),
    Padded = etui@text:pad_right(Truncated, Width),
    Buf2 = etui@buffer:set_string(Buf, {position, erlang:element(2, erlang:element(2, Area)), Y}, Padded, etui@style:new(erlang:element(4, W), erlang:element(5, W), etui@style:none())),
    case Is_cursor_row andalso (erlang:element(3, State) < Width) of
        false ->
            Buf2;

        true ->
            Cursor_ch = grapheme_at_cell(Line, erlang:element(3, State)),
            etui@buffer:set_string(Buf2, {position, erlang:element(2, erlang:element(2, Area)) + erlang:element(3, State), Y}, Cursor_ch, erlang:element(6, W))
    end.

-file("src/etui/widgets/textarea.gleam", 361).
-spec render_lines(etui@buffer:buffer(), etui@geometry:rect(), text_area(), text_area_state(), integer(), integer()) -> etui@buffer:buffer().
render_lines(Buf, Area, W, State, Scroll, Row_offset) ->
    case Row_offset >= erlang:element(3, erlang:element(3, Area)) of
        true ->
            Buf;

        false ->
            Line_idx = Scroll + Row_offset,
            Line = get_line(erlang:element(2, State), Line_idx),
            Y = erlang:element(3, erlang:element(2, Area)) + Row_offset,
            Is_cursor_row = Line_idx =:= erlang:element(4, State),
            Buf2 = render_line(Buf, Area, W, State, Line, Y, Is_cursor_row),
            render_lines(Buf2, Area, W, State, Scroll, Row_offset + 1)
    end.

-file("src/etui/widgets/textarea.gleam", 345).
-spec render(etui@buffer:buffer(), etui@geometry:rect(), text_area(), text_area_state()) -> etui@buffer:buffer().
-doc(~" Render the textarea. Scrolls vertically so the cursor line is visible.
 Highlights the cursor cell with `cursor_style`.").
render(Buf, Area, W, State) ->
    case (erlang:element(3, erlang:element(3, Area)) =< 0) orelse (erlang:element(2, erlang:element(3, Area)) =< 0) of
        true ->
            Buf;

        false ->
            Visible_h = erlang:element(3, erlang:element(3, Area)),
            Scroll = scroll_offset(erlang:element(4, State), Visible_h),
            render_lines(Buf, Area, W, State, Scroll, 0)
    end.

