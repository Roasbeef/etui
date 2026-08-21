-module(etui@buffer).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([continuation_cell/1, area/1, width/1, height/1, cell_symbol/1, cell_style/1, cell_fg/1, cell_bg/1, cell_modifier/1, cell_underline_color/1, is_continuation/1, empty_cell/0, cell_link/1, buffer_new/1, buffer_new_filled/3, get_cell/2, set_cell/3, set_string_linked/5, set_string/4, clear/2, blit/4, set_style/3, diff/2, to_ansi/1, patches_to_ansi/1, diff_to_ansi/2]).
-export_type([cell_array/0, draft/0, cell_content/0, cell/0, buffer/0, buffer_op/0, buf_view/0, run_style/0]).

-type cell_array() :: any().

-type draft() :: any().

-type cell_content() :: {content, binary(), integer()} | continuation.

-type cell() :: {cell, cell_content(), etui@style:style(), binary()}.

-opaque buffer() :: {buffer, etui@geometry:rect(), cell_array()}.

-type buffer_op() :: {patch, etui@geometry:position(), list(cell())}.

-type buf_view() :: {buf_view, cell_array(), integer(), integer(), integer(), integer(), integer()}.

-type run_style() :: {run_style, etui@style:style(), binary()}.

-file("src/etui/buffer.gleam", 284).
-spec continuation_cell(etui@style:style()) -> cell().
-doc(~" Continuation cell (second column of a wide grapheme).").
continuation_cell(S) ->
    {cell, continuation, etui@style:resolve(S), ~""}.

-file("src/etui/buffer.gleam", 127).
-spec fill_draft(draft(), integer(), integer(), list(binary()), etui@style:style(), binary()) -> draft().
fill_draft(Arr, Idx, Max_idx, Gs, S, Link) ->
    case Idx >= Max_idx of
        true ->
            Arr;

        false ->
            case Gs of
                [] ->
                    Arr;

                [G | Rest] ->
                    W = etui@text:grapheme_cell_width(G),
                    Cell = {cell, {content, G, W}, S, Link},
                    case W >= 2 of
                        true when (Idx + 1) >= Max_idx ->
                            fill_draft(Arr, Idx + 1, Max_idx, Rest, S, Link);

                        true ->
                            fill_draft(etui_buffer_array_ffi:draft_set(Idx + 1, continuation_cell(S), etui_buffer_array_ffi:draft_set(Idx, Cell, Arr)), Idx + 2, Max_idx, Rest, S, Link);

                        false ->
                            fill_draft(etui_buffer_array_ffi:draft_set(Idx, Cell, Arr), Idx + 1, Max_idx, Rest, S, Link)
                    end
            end
    end.

-file("src/etui/buffer.gleam", 116).
-spec fill_graphemes(cell_array(), integer(), integer(), list(binary()), etui@style:style(), binary()) -> cell_array().
fill_graphemes(Arr, Idx, Max_idx, Gs, S, Link) ->
    etui_buffer_array_ffi:commit(fill_draft(etui_buffer_array_ffi:draft(Arr), Idx, Max_idx, Gs, S, Link)).

-file("src/etui/buffer.gleam", 74).
-spec fill_all_rows_gleam(cell_array(), integer(), integer(), integer(), binary(), etui@style:style(), binary()) -> cell_array().
fill_all_rows_gleam(Arr, Row, Height, Width, Str, S, Link) ->
    case Row >= Height of
        true ->
            Arr;

        false ->
            Start = Row * Width,
            Arr2 = fill_graphemes(Arr, Start, Start + Width, gleam@string:to_graphemes(Str), S, Link),
            fill_all_rows_gleam(Arr2, Row + 1, Height, Width, Str, S, Link)
    end.

-file("src/etui/buffer.gleam", 216).
-spec area(buffer()) -> etui@geometry:rect().
-doc(~" The rect this buffer covers.").
area(Buf) ->
    erlang:element(2, Buf).

-file("src/etui/buffer.gleam", 221).
-spec width(buffer()) -> integer().
-doc(~" Width in cells.").
width(Buf) ->
    erlang:element(2, erlang:element(3, erlang:element(2, Buf))).

-file("src/etui/buffer.gleam", 226).
-spec height(buffer()) -> integer().
-doc(~" Height in rows.").
height(Buf) ->
    erlang:element(3, erlang:element(3, erlang:element(2, Buf))).

-file("src/etui/buffer.gleam", 231).
-spec cell_symbol(cell()) -> binary().
-doc(~" Symbol string of a cell. Returns \" \" for Continuation cells.").
cell_symbol(Cell) ->
    case erlang:element(2, Cell) of
        {content, S, _} ->
            S;

        continuation ->
            ~" "
    end.

-file("src/etui/buffer.gleam", 239).
-spec cell_style(cell()) -> etui@style:style().
-doc(~" Whole style of a cell.").
cell_style(Cell) ->
    erlang:element(3, Cell).

-file("src/etui/buffer.gleam", 244).
-spec cell_fg(cell()) -> etui@style:color().
-doc(~" Foreground color of a cell.").
cell_fg(Cell) ->
    erlang:element(2, erlang:element(3, Cell)).

-file("src/etui/buffer.gleam", 249).
-spec cell_bg(cell()) -> etui@style:color().
-doc(~" Background color of a cell.").
cell_bg(Cell) ->
    erlang:element(3, erlang:element(3, Cell)).

-file("src/etui/buffer.gleam", 254).
-spec cell_modifier(cell()) -> etui@style:modifier().
-doc(~" Text modifier of a cell.").
cell_modifier(Cell) ->
    erlang:element(4, erlang:element(3, Cell)).

-file("src/etui/buffer.gleam", 259).
-spec cell_underline_color(cell()) -> etui@style:color().
-doc(~" Underline color of a cell.").
cell_underline_color(Cell) ->
    erlang:element(6, erlang:element(3, Cell)).

-file("src/etui/buffer.gleam", 264).
-spec is_continuation(cell()) -> boolean().
-doc(~" True if this cell is the second column of a wide grapheme (never rendered directly).").
is_continuation(Cell) ->
    case erlang:element(2, Cell) of
        continuation ->
            true;

        _ ->
            false
    end.

-file("src/etui/buffer.gleam", 275).
-spec empty_cell() -> cell().
-doc(~" Empty cell (space, default style, no link).").
empty_cell() ->
    {cell, {content, ~" ", 1}, etui@style:default_style(), ~""}.

-file("src/etui/buffer.gleam", 289).
-spec cell_link(cell()) -> binary().
-doc(~" Accessor: OSC 8 hyperlink URI of a cell (empty = no link).").
cell_link(Cell) ->
    erlang:element(4, Cell).

-file("src/etui/buffer.gleam", 294).
-spec buffer_new(etui@geometry:rect()) -> buffer().
-doc(~" New buffer with given area. All cells start as `empty_cell()`.").
buffer_new(Area) ->
    Size = gleam@int:max(erlang:element(2, erlang:element(3, Area)) * erlang:element(3, erlang:element(3, Area)), 0),
    {buffer, Area, etui_buffer_array_ffi:new(Size, empty_cell())}.

-file("src/etui/buffer.gleam", 302).
-spec buffer_new_filled(etui@geometry:rect(), binary(), etui@style:style()) -> buffer().
-doc(~" Create a buffer with every row pre-filled with `row_text`.
 Uses bulk array construction: one pass instead of `buffer_new` followed by
 a `set_string` for every row.").
buffer_new_filled(Area, Row_text, S) ->
    Default = empty_cell(),
    {buffer, Area, etui_buffer_array_ffi:fill_all_rows(erlang:element(2, erlang:element(3, Area)), erlang:element(3, erlang:element(3, Area)), Row_text, etui@style:resolve(S), ~"", Default)}.

-file("src/etui/buffer.gleam", 324).
-spec pos_to_idx(etui@geometry:rect(), etui@geometry:position()) -> integer().
pos_to_idx(Area, Pos) ->
    ((erlang:element(3, Pos) - erlang:element(3, erlang:element(2, Area))) * erlang:element(2, erlang:element(3, Area))) + (erlang:element(2, Pos) - erlang:element(2, erlang:element(2, Area))).

-file("src/etui/buffer.gleam", 332).
-spec get_cell(buffer(), etui@geometry:position()) -> cell().
-doc(~" Get cell at position. Returns empty_cell() for out-of-bounds.").
get_cell(Buffer, Pos) ->
    case etui@geometry:contains(erlang:element(2, Buffer), Pos) of
        false ->
            empty_cell();

        true ->
            etui_buffer_array_ffi:get(pos_to_idx(erlang:element(2, Buffer), Pos), erlang:element(3, Buffer))
    end.

-file("src/etui/buffer.gleam", 344).
-spec set_cell(buffer(), etui@geometry:position(), cell()) -> buffer().
-doc(~" Set cell at position. Out-of-bounds writes are ignored.

 The cell's style is resolved on the way in, like every other write path,
 so a hand-built `Cell` cannot smuggle an unspent `sub_modifier` into the
 grid and make an identical-looking cell compare unequal.").
set_cell(Buffer, Pos, Cell) ->
    Cell@1 = {cell, erlang:element(2, Cell), etui@style:resolve(erlang:element(3, Cell)), erlang:element(4, Cell)},
    case etui@geometry:contains(erlang:element(2, Buffer), Pos) of
        true ->
            {buffer, erlang:element(2, Buffer), etui_buffer_array_ffi:set(pos_to_idx(erlang:element(2, Buffer), Pos), Cell@1, erlang:element(3, Buffer))};

        false ->
            Buffer
    end.

-file("src/etui/buffer.gleam", 369).
-spec set_string_linked(buffer(), etui@geometry:position(), binary(), etui@style:style(), binary()) -> buffer().
-doc(~" Set cells from a string with an OSC 8 hyperlink URI.
 Pass `\"\"` for no link (same as `set_string`).").
set_string_linked(Buffer, Pos, Str, S, Link) ->
    case etui@geometry:contains(erlang:element(2, Buffer), Pos) of
        false ->
            Buffer;

        true ->
            Start_idx = pos_to_idx(erlang:element(2, Buffer), Pos),
            Row_end = ((erlang:element(3, Pos) - erlang:element(3, erlang:element(2, erlang:element(2, Buffer)))) + 1) * erlang:element(2, erlang:element(3, erlang:element(2, Buffer))),
            {buffer, erlang:element(2, Buffer), etui_buffer_array_ffi:fill_string(erlang:element(3, Buffer), Start_idx, Row_end, Str, etui@style:resolve(S), Link)}
    end.

-file("src/etui/buffer.gleam", 358).
-spec set_string(buffer(), etui@geometry:position(), binary(), etui@style:style()) -> buffer().
-doc(~" Set cells from a string starting at `pos`. No hyperlink.
 Wide graphemes (width=2) take one Cell + one Continuation cell.").
set_string(Buffer, Pos, Str, S) ->
    set_string_linked(Buffer, Pos, Str, S, ~"").

-file("src/etui/buffer.gleam", 436).
-spec clear_row(draft(), cell(), integer(), integer()) -> draft().
clear_row(Cells, Blank, Idx, Idx_max) ->
    case Idx >= Idx_max of
        true ->
            Cells;

        false ->
            clear_row(etui_buffer_array_ffi:draft_set(Idx, Blank, Cells), Blank, Idx + 1, Idx_max)
    end.

-file("src/etui/buffer.gleam", 445).
-spec row_base(etui@geometry:rect(), integer()) -> integer().
row_base(Area, Y) ->
    ((Y - erlang:element(3, erlang:element(2, Area))) * erlang:element(2, erlang:element(3, Area))) - erlang:element(2, erlang:element(2, Area)).

-file("src/etui/buffer.gleam", 418).
-spec clear_rows(etui@geometry:rect(), draft(), etui@geometry:rect(), cell(), integer()) -> draft().
clear_rows(Area, Cells, R, Blank, Y) ->
    case Y >= etui@geometry:bottom(R) of
        true ->
            Cells;

        false ->
            Base = row_base(Area, Y),
            Cells2 = clear_row(Cells, Blank, Base + erlang:element(2, erlang:element(2, R)), Base + etui@geometry:right(R)),
            clear_rows(Area, Cells2, R, Blank, Y + 1)
    end.

-file("src/etui/buffer.gleam", 401).
-spec clear(buffer(), etui@geometry:rect()) -> buffer().
-doc(~" Clear all cells in a rect (reset to empty_cell).
 The rect is clipped to the buffer first, so the inner loop needs no
 per-cell bounds check and the `Buffer` record is rebuilt once, not per cell.").
clear(Buffer, Rect) ->
    case etui@geometry:intersect(erlang:element(2, Buffer), Rect) of
        {error, _} ->
            Buffer;

        {ok, R} ->
            {buffer, erlang:element(2, Buffer), etui_buffer_array_ffi:commit(clear_rows(erlang:element(2, Buffer), etui_buffer_array_ffi:draft(erlang:element(3, Buffer)), R, empty_cell(), erlang:element(3, erlang:element(2, R))))}
    end.

-file("src/etui/buffer.gleam", 553).
-spec clip_edge(cell(), integer(), integer(), integer()) -> cell().
clip_edge(Cell, X, X_min, X_max) ->
    case erlang:element(2, Cell) of
        continuation when X =:= X_min ->
            empty_cell();

        {content, _, W} when (W >= 2) andalso (X =:= (X_max - 1)) ->
            empty_cell();

        _ ->
            Cell
    end.

-file("src/etui/buffer.gleam", 523).
-spec blit_row(cell_array(), draft(), integer(), integer(), integer(), integer(), integer()) -> draft().
blit_row(Src_cells, Cells, Src_base, Dst_base, X, X_min, X_max) ->
    case X >= X_max of
        true ->
            Cells;

        false ->
            Cell = etui_buffer_array_ffi:get(Src_base + X, Src_cells),
            blit_row(Src_cells, etui_buffer_array_ffi:draft_set(Dst_base + X, clip_edge(Cell, X, X_min, X_max), Cells), Src_base, Dst_base, X + 1, X_min, X_max)
    end.

-file("src/etui/buffer.gleam", 493).
-spec blit_rows(buffer(), etui@geometry:rect(), draft(), etui@geometry:rect(), integer(), integer(), integer()) -> draft().
blit_rows(Src, Dst_area, Cells, D, Dx, Dy, Y) ->
    case Y >= etui@geometry:bottom(D) of
        true ->
            Cells;

        false ->
            Src_base = row_base(erlang:element(2, Src), Y - Dy) - Dx,
            Dst_base = row_base(Dst_area, Y),
            Cells2 = blit_row(erlang:element(3, Src), Cells, Src_base, Dst_base, erlang:element(2, erlang:element(2, D)), erlang:element(2, erlang:element(2, D)), etui@geometry:right(D)),
            blit_rows(Src, Dst_area, Cells2, D, Dx, Dy, Y + 1)
    end.

-file("src/etui/buffer.gleam", 454).
-spec blit(buffer(), buffer(), etui@geometry:rect(), etui@geometry:position()) -> buffer().
-doc(~" Copy `src_rect` out of `src` into `dst`, placing its top-left at `dst_pos`.
 Clipped against both buffers; anything outside either is skipped.

 Use to composite an off-screen buffer (a scroll canvas, a cached panel)
 into the frame without going cell by cell from the caller.").
blit(Dst, Src, Src_rect, Dst_pos) ->
    Dx = erlang:element(2, Dst_pos) - erlang:element(2, erlang:element(2, Src_rect)),
    Dy = erlang:element(3, Dst_pos) - erlang:element(3, erlang:element(2, Src_rect)),
    case etui@geometry:intersect(erlang:element(2, Src), Src_rect) of
        {error, _} ->
            Dst;

        {ok, S} ->
            Translated = {rect, {position, erlang:element(2, erlang:element(2, S)) + Dx, erlang:element(3, erlang:element(2, S)) + Dy}, erlang:element(3, S)},
            case etui@geometry:intersect(erlang:element(2, Dst), Translated) of
                {error, _} ->
                    Dst;

                {ok, D} ->
                    {buffer, erlang:element(2, Dst), etui_buffer_array_ffi:commit(blit_rows(Src, erlang:element(2, Dst), etui_buffer_array_ffi:draft(erlang:element(3, Dst)), D, Dx, Dy, erlang:element(3, erlang:element(2, D))))}
            end
    end.

-file("src/etui/buffer.gleam", 603).
-spec style_row(draft(), etui@style:style(), integer(), integer()) -> draft().
style_row(Cells, S, Idx, Idx_max) ->
    case Idx >= Idx_max of
        true ->
            Cells;

        false ->
            Cell = etui_buffer_array_ffi:draft_get(Idx, Cells),
            Restyled = {cell, erlang:element(2, Cell), S, erlang:element(4, Cell)},
            style_row(etui_buffer_array_ffi:draft_set(Idx, Restyled, Cells), S, Idx + 1, Idx_max)
    end.

-file("src/etui/buffer.gleam", 585).
-spec style_rows(etui@geometry:rect(), draft(), etui@geometry:rect(), etui@style:style(), integer()) -> draft().
style_rows(Area, Cells, R, S, Y) ->
    case Y >= etui@geometry:bottom(R) of
        true ->
            Cells;

        false ->
            Base = row_base(Area, Y),
            Cells2 = style_row(Cells, S, Base + erlang:element(2, erlang:element(2, R)), Base + etui@geometry:right(R)),
            style_rows(Area, Cells2, R, S, Y + 1)
    end.

-file("src/etui/buffer.gleam", 564).
-spec set_style(buffer(), etui@geometry:rect(), etui@style:style()) -> buffer().
-doc(~" Restyle every cell in `rect`, keeping its content.
 Use to tint a region (selection highlight, disabled panel) after the
 content has been drawn.").
set_style(Buffer, Rect, S) ->
    case etui@geometry:intersect(erlang:element(2, Buffer), Rect) of
        {error, _} ->
            Buffer;

        {ok, R} ->
            {buffer, erlang:element(2, Buffer), etui_buffer_array_ffi:commit(style_rows(erlang:element(2, Buffer), etui_buffer_array_ffi:draft(erlang:element(3, Buffer)), R, etui@style:resolve(S), erlang:element(3, erlang:element(2, R))))}
    end.

-file("src/etui/buffer.gleam", 630).
-spec buf_view(buffer()) -> buf_view().
buf_view(Buf) ->
    {buf_view, erlang:element(3, Buf), erlang:element(3, erlang:element(2, erlang:element(2, Buf))), erlang:element(2, erlang:element(2, erlang:element(2, Buf))), erlang:element(2, erlang:element(3, erlang:element(2, Buf))), erlang:element(3, erlang:element(3, erlang:element(2, Buf))), erlang:element(2, erlang:element(3, erlang:element(2, Buf))) * erlang:element(3, erlang:element(3, erlang:element(2, Buf)))}.

-file("src/etui/buffer.gleam", 642).
-spec bv_cell_at(buf_view(), integer(), integer()) -> cell().
bv_cell_at(Bv, Row_base, X) ->
    Idx = (Row_base + X) - erlang:element(4, Bv),
    case (Idx >= 0) andalso (Idx < erlang:element(7, Bv)) of
        true ->
            etui_buffer_array_ffi:get(Idx, erlang:element(2, Bv));

        false ->
            empty_cell()
    end.

-file("src/etui/buffer.gleam", 755).
-spec same_style(etui@style:style(), etui@style:style()) -> boolean().
same_style(A, B) ->
    etui_buffer_array_ffi:same(A, B) orelse (A =:= B).

-file("src/etui/buffer.gleam", 746).
-spec cells_equal(cell(), cell()) -> boolean().
cells_equal(A, B) ->
    etui_buffer_array_ffi:same(A, B) orelse (((erlang:element(2, A) =:= erlang:element(2, B)) andalso (erlang:element(4, A) =:= erlang:element(4, B))) andalso same_style(erlang:element(3, A), erlang:element(3, B))).

-file("src/etui/buffer.gleam", 711).
-spec collect_run(buf_view(), buf_view(), integer(), integer(), integer(), integer(), list(cell())) -> {list(cell()), integer()}.
collect_run(Prev, Next, Prev_rb, Next_rb, X, X_max, Run) ->
    case X >= X_max of
        true ->
            {lists:reverse(Run), X};

        false ->
            Prev_cell = bv_cell_at(Prev, Prev_rb, X),
            Next_cell = bv_cell_at(Next, Next_rb, X),
            case cells_equal(Prev_cell, Next_cell) of
                true ->
                    {lists:reverse(Run), X};

                false ->
                    collect_run(Prev, Next, Prev_rb, Next_rb, X + 1, X_max, [Next_cell | Run])
            end
    end.

-file("src/etui/buffer.gleam", 680).
-spec diff_row(buf_view(), buf_view(), integer(), integer(), integer(), integer(), integer(), list(buffer_op())) -> list(buffer_op()).
diff_row(Prev, Next, Prev_rb, Next_rb, Y, X, X_max, Rev_acc) ->
    case X >= X_max of
        true ->
            Rev_acc;

        false ->
            Prev_cell = bv_cell_at(Prev, Prev_rb, X),
            Next_cell = bv_cell_at(Next, Next_rb, X),
            case cells_equal(Prev_cell, Next_cell) of
                true ->
                    diff_row(Prev, Next, Prev_rb, Next_rb, Y, X + 1, X_max, Rev_acc);

                false ->
                    Pos = {position, X, Y},
                    {Run, Next_x} = collect_run(Prev, Next, Prev_rb, Next_rb, X, X_max, []),
                    diff_row(Prev, Next, Prev_rb, Next_rb, Y, Next_x, X_max, [{patch, Pos, Run} | Rev_acc])
            end
    end.

-file("src/etui/buffer.gleam", 659).
-spec diff_rows(buf_view(), buf_view(), integer(), integer(), integer(), integer(), list(buffer_op())) -> list(buffer_op()).
diff_rows(Prev, Next, Y, Y_max, X_min, X_max, Rev_acc) ->
    case Y >= Y_max of
        true ->
            lists:reverse(Rev_acc);

        false ->
            Prev_rb = (Y - erlang:element(3, Prev)) * erlang:element(5, Prev),
            Next_rb = (Y - erlang:element(3, Next)) * erlang:element(5, Next),
            Rev_acc2 = diff_row(Prev, Next, Prev_rb, Next_rb, Y, X_min, X_max, Rev_acc),
            diff_rows(Prev, Next, Y + 1, Y_max, X_min, X_max, Rev_acc2)
    end.

-file("src/etui/buffer.gleam", 943).
-spec max_int(integer(), integer()) -> integer().
max_int(A, B) ->
    case A > B of
        true ->
            A;

        false ->
            B
    end.

-file("src/etui/buffer.gleam", 936).
-spec min_int(integer(), integer()) -> integer().
min_int(A, B) ->
    case A < B of
        true ->
            A;

        false ->
            B
    end.

-file("src/etui/buffer.gleam", 651).
-spec diff(buffer(), buffer()) -> list(buffer_op()).
-doc(~" Compute minimal diff between two buffers as a list of patches.").
diff(Prev, Next) ->
    Y_min = min_int(erlang:element(3, erlang:element(2, erlang:element(2, Prev))), erlang:element(3, erlang:element(2, erlang:element(2, Next)))),
    Y_max = max_int(etui@geometry:bottom(erlang:element(2, Prev)), etui@geometry:bottom(erlang:element(2, Next))),
    X_min = min_int(erlang:element(2, erlang:element(2, erlang:element(2, Prev))), erlang:element(2, erlang:element(2, erlang:element(2, Next)))),
    X_max = max_int(etui@geometry:right(erlang:element(2, Prev)), etui@geometry:right(erlang:element(2, Next))),
    diff_rows(buf_view(Prev), buf_view(Next), Y_min, Y_max, X_min, X_max, []).

-file("src/etui/buffer.gleam", 779).
-spec blank_run_style() -> run_style().
blank_run_style() ->
    {run_style, etui@style:default_style(), ~""}.

-file("src/etui/buffer.gleam", 783).
-spec run_style_active(run_style()) -> boolean().
run_style_active(Rs) ->
    ((((etui@style:ansi_fg(erlang:element(2, erlang:element(2, Rs))) /= ~"") orelse (etui@style:ansi_bg(erlang:element(3, erlang:element(2, Rs))) /= ~"")) orelse (etui@style:ansi_modifier(erlang:element(4, erlang:element(2, Rs))) /= ~"")) orelse (etui@style:ansi_underline_color(erlang:element(6, erlang:element(2, Rs))) /= ~"")) orelse (erlang:element(3, Rs) /= ~"").

-file("src/etui/buffer.gleam", 921).
-spec osc8_open(binary()) -> binary().
osc8_open(Uri) ->
    <<<<"\x{001B}]8;;"/utf8, Uri/binary>>/binary, "\x{001B}\\"/utf8>>.

-file("src/etui/buffer.gleam", 925).
-spec osc8_close() -> binary().
osc8_close() ->
    ~"\x{001B}]8;;\x{001B}\\".

-file("src/etui/buffer.gleam", 794).
-spec emit_cell(run_style(), cell()) -> {binary(), run_style()}.
emit_cell(Rs, Cell) ->
    case is_continuation(Cell) of
        true ->
            {~"", Rs};

        false ->
            Same = (erlang:element(4, Cell) =:= erlang:element(3, Rs)) andalso same_style(erlang:element(3, Cell), erlang:element(2, Rs)),
            case Same of
                true ->
                    {cell_symbol(Cell), Rs};

                false ->
                    Link_close = case erlang:element(3, Rs) of
                        ~"" ->
                            ~"";

                        _ ->
                            osc8_close()
                    end,
                    Reset_seq = case run_style_active(Rs) of
                        true ->
                            etui@style:ansi_reset();

                        false ->
                            ~""
                    end,
                    Fg_seq = etui@style:ansi_fg(erlang:element(2, erlang:element(3, Cell))),
                    Bg_seq = etui@style:ansi_bg(erlang:element(3, erlang:element(3, Cell))),
                    Mod_seq = etui@style:ansi_modifier(erlang:element(4, erlang:element(3, Cell))),
                    Ul_seq = etui@style:ansi_underline_color(erlang:element(6, erlang:element(3, Cell))),
                    Link_open = case erlang:element(4, Cell) of
                        ~"" ->
                            ~"";

                        Uri ->
                            osc8_open(Uri)
                    end,
                    New_rs = {run_style, erlang:element(3, Cell), erlang:element(4, Cell)},
                    {<<<<<<<<<<<<<<Link_close/binary, Reset_seq/binary>>/binary, Fg_seq/binary>>/binary, Bg_seq/binary>>/binary, Mod_seq/binary>>/binary, Ul_seq/binary>>/binary, Link_open/binary>>/binary, (cell_symbol(Cell))/binary>>, New_rs}
            end
    end.

-file("src/etui/buffer.gleam", 866).
-spec to_ansi_row(buf_view(), integer(), integer(), run_style(), binary()) -> {binary(), run_style()}.
to_ansi_row(Bv, Row_base, Col, Rs, Acc) ->
    case Col >= erlang:element(5, Bv) of
        true ->
            {Acc, Rs};

        false ->
            Cell = bv_cell_at(Bv, Row_base, erlang:element(4, Bv) + Col),
            {S, New_rs} = emit_cell(Rs, Cell),
            to_ansi_row(Bv, Row_base, Col + 1, New_rs, <<Acc/binary, S/binary>>)
    end.

-file("src/etui/buffer.gleam", 929).
-spec move_cursor_seq(integer(), integer()) -> binary().
move_cursor_seq(X, Y) ->
    <<<<<<<<"\x{001B}["/utf8, (erlang:integer_to_binary(Y + 1))/binary>>/binary, ";"/utf8>>/binary, (erlang:integer_to_binary(X + 1))/binary>>/binary, "H"/utf8>>.

-file("src/etui/buffer.gleam", 850).
-spec to_ansi_rows(buf_view(), integer(), run_style(), binary()) -> {binary(), run_style()}.
to_ansi_rows(Bv, Row, Rs, Acc) ->
    case Row >= erlang:element(6, Bv) of
        true ->
            {Acc, Rs};

        false ->
            Move = move_cursor_seq(erlang:element(4, Bv), erlang:element(3, Bv) + Row),
            {Row_str, New_rs} = to_ansi_row(Bv, Row * erlang:element(5, Bv), 0, Rs, ~""),
            to_ansi_rows(Bv, Row + 1, New_rs, <<<<Acc/binary, Move/binary>>/binary, Row_str/binary>>)
    end.

-file("src/etui/buffer.gleam", 840).
-spec to_ansi(buffer()) -> binary().
-doc(~" Full-buffer render to an ANSI string.
 Emits a MoveCursor for every row, then each cell with style transitions
 only when the style actually changes between adjacent cells.
 Use for the first frame or after a terminal resize.").
to_ansi(Buf) ->
    {Output, Final_rs} = to_ansi_rows(buf_view(Buf), 0, blank_run_style(), ~""),
    Trailing = case run_style_active(Final_rs) of
        true ->
            etui@style:ansi_reset();

        false ->
            ~""
    end,
    <<Output/binary, Trailing/binary>>.

-file("src/etui/buffer.gleam", 888).
-spec patches_to_ansi(list(buffer_op())) -> binary().
-doc(~" Convert a list of `BufferOp` patches to an ANSI string.
 Each patch moves the cursor once, then writes a run of cells.
 Style is tracked across the entire patch list, cursor moves do not
 reset terminal style, so we avoid redundant escape sequences.
 Cheaper than `to_ansi` when only a small fraction of cells changed.").
patches_to_ansi(Ops) ->
    case Ops of
        [] ->
            ~"";

        _ ->
            {Output, Final_rs} = gleam@list:fold(Ops, {~"", blank_run_style()}, fun(Acc, Op) ->
                {Str, Rs} = Acc,
                Move = move_cursor_seq(erlang:element(2, erlang:element(2, Op)), erlang:element(3, erlang:element(2, Op))),
                {Cells_str, New_rs} = gleam@list:fold(erlang:element(3, Op), {~"", Rs}, fun(C_acc, Cell) ->
                    {C_str, C_rs} = C_acc,
                    {S, Next_rs} = emit_cell(C_rs, Cell),
                    {<<C_str/binary, S/binary>>, Next_rs}
                end),
                {<<<<Str/binary, Move/binary>>/binary, Cells_str/binary>>, New_rs}
            end),
            Trailing = case run_style_active(Final_rs) of
                true ->
                    etui@style:ansi_reset();

                false ->
                    ~""
            end,
            <<Output/binary, Trailing/binary>>
    end.

-file("src/etui/buffer.gleam", 916).
-spec diff_to_ansi(buffer(), buffer()) -> binary().
-doc(~" Diff `prev` against `curr` and return the minimal ANSI to bring the
 terminal from `prev`'s state to `curr`'s state.
 On the first frame (or after resize) pass an empty buffer as `prev`.").
diff_to_ansi(Prev, Curr) ->
    patches_to_ansi(diff(Prev, Curr)).

