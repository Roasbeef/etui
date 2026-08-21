-module(etui@widgets@block).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([block_new/0, with_bg_fill/1, with_border/2, with_title/3, with_title_styled/3, with_padding/5, with_title_alignment/2, with_style/3, with_colors/3, render/3, inner/2]).
-export_type([border/0, title_position/0, block/0]).

-type border() :: none | single | double | rounded.

-type title_position() :: top | bottom.

-type block() :: {block, border(), binary(), list(etui@span:span()), title_position(), etui@text:alignment(), integer(), integer(), integer(), integer(), etui@style:color(), etui@style:color(), boolean()}.

-file("src/etui/widgets/block.gleam", 49).
-spec block_new() -> block().
-doc(~" New block with no border, no title, no padding, default colors.").
block_new() ->
    {block, none, ~"", [], top, left, 0, 0, 0, 0, default, default, false}.

-file("src/etui/widgets/block.gleam", 67).
-spec with_bg_fill(block()) -> block().
-doc(~" Fill the inner area with the block's background color.").
with_bg_fill(Blk) ->
    {block, erlang:element(2, Blk), erlang:element(3, Blk), erlang:element(4, Blk), erlang:element(5, Blk), erlang:element(6, Blk), erlang:element(7, Blk), erlang:element(8, Blk), erlang:element(9, Blk), erlang:element(10, Blk), erlang:element(11, Blk), erlang:element(12, Blk), true}.

-file("src/etui/widgets/block.gleam", 72).
-spec with_border(block(), border()) -> block().
-doc(~" Set the border style. `Single` draws ┌─┐│└─┘, `Double` ╔═╗║╚═╝, `Rounded` ╭─╮│╰─╯.").
with_border(Blk, Border) ->
    {block, Border, erlang:element(3, Blk), erlang:element(4, Blk), erlang:element(5, Blk), erlang:element(6, Blk), erlang:element(7, Blk), erlang:element(8, Blk), erlang:element(9, Blk), erlang:element(10, Blk), erlang:element(11, Blk), erlang:element(12, Blk), erlang:element(13, Blk)}.

-file("src/etui/widgets/block.gleam", 77).
-spec with_title(block(), binary(), title_position()) -> block().
-doc(~" Set a title string and whether it appears on the top or bottom border.").
with_title(Blk, Title, Position) ->
    {block, erlang:element(2, Blk), Title, [], Position, erlang:element(6, Blk), erlang:element(7, Blk), erlang:element(8, Blk), erlang:element(9, Blk), erlang:element(10, Blk), erlang:element(11, Blk), erlang:element(12, Blk), erlang:element(13, Blk)}.

-file("src/etui/widgets/block.gleam", 92).
-spec with_title_styled(block(), list(etui@span:span()), title_position()) -> block().
-doc(~" Set a styled title from a list of `span.Span` values.
 Takes precedence over `with_title` when non-empty.

 ```gleam
 block.block_new()
 |> block.with_border(block.Rounded)
 |> block.with_title_styled([
   span.span_styled(\"★ \", style.bold_style() |> style.with_fg(style.Rgb(255,215,0))),
   span.span_plain(\"Dashboard\"),
 ], block.Top)
 ```").
with_title_styled(Blk, Spans, Position) ->
    {block, erlang:element(2, Blk), ~"", Spans, Position, erlang:element(6, Blk), erlang:element(7, Blk), erlang:element(8, Blk), erlang:element(9, Blk), erlang:element(10, Blk), erlang:element(11, Blk), erlang:element(12, Blk), erlang:element(13, Blk)}.

-file("src/etui/widgets/block.gleam", 101).
-spec with_padding(block(), integer(), integer(), integer(), integer()) -> block().
-doc(~" Set inner padding (cells between border and content).").
with_padding(Blk, Top, Bottom, Left, Right) ->
    {block, erlang:element(2, Blk), erlang:element(3, Blk), erlang:element(4, Blk), erlang:element(5, Blk), erlang:element(6, Blk), Top, Bottom, Left, Right, erlang:element(11, Blk), erlang:element(12, Blk), erlang:element(13, Blk)}.

-file("src/etui/widgets/block.gleam", 118).
-spec with_title_alignment(block(), etui@text:alignment()) -> block().
-doc(~" Set the horizontal alignment of the title within the border.").
with_title_alignment(Blk, Alignment) ->
    {block, erlang:element(2, Blk), erlang:element(3, Blk), erlang:element(4, Blk), erlang:element(5, Blk), Alignment, erlang:element(7, Blk), erlang:element(8, Blk), erlang:element(9, Blk), erlang:element(10, Blk), erlang:element(11, Blk), erlang:element(12, Blk), erlang:element(13, Blk)}.

-file("src/etui/widgets/block.gleam", 123).
-spec with_style(block(), etui@style:color(), etui@style:color()) -> block().
-doc(~" Set foreground and background colors for the border and title.").
with_style(Blk, Fg, Bg) ->
    {block, erlang:element(2, Blk), erlang:element(3, Blk), erlang:element(4, Blk), erlang:element(5, Blk), erlang:element(6, Blk), erlang:element(7, Blk), erlang:element(8, Blk), erlang:element(9, Blk), erlang:element(10, Blk), Fg, Bg, erlang:element(13, Blk)}.

-file("src/etui/widgets/block.gleam", 128).
-spec with_colors(block(), etui@style:color(), etui@style:color()) -> block().
-doc(~" Alias for `with_style(fg, bg)`, consistent with other widget naming.").
with_colors(Blk, Fg, Bg) ->
    {block, erlang:element(2, Blk), erlang:element(3, Blk), erlang:element(4, Blk), erlang:element(5, Blk), erlang:element(6, Blk), erlang:element(7, Blk), erlang:element(8, Blk), erlang:element(9, Blk), erlang:element(10, Blk), Fg, Bg, erlang:element(13, Blk)}.

-file("src/etui/widgets/block.gleam", 332).
-spec inner_area(etui@geometry:rect(), block()) -> etui@geometry:rect().
inner_area(Area, Blk) ->
    Border_offset = case erlang:element(2, Blk) of
        none ->
            0;

        single ->
            1;

        double ->
            1;

        rounded ->
            1
    end,
    X = (erlang:element(2, erlang:element(2, Area)) + erlang:element(9, Blk)) + Border_offset,
    Y = (erlang:element(3, erlang:element(2, Area)) + erlang:element(7, Blk)) + Border_offset,
    W = gleam@int:max(0, ((erlang:element(2, erlang:element(3, Area)) - erlang:element(9, Blk)) - erlang:element(10, Blk)) - (Border_offset * 2)),
    H = gleam@int:max(0, ((erlang:element(3, erlang:element(3, Area)) - erlang:element(7, Blk)) - erlang:element(8, Blk)) - (Border_offset * 2)),
    {rect, {position, X, Y}, {size, W, H}}.

-file("src/etui/widgets/block.gleam", 296).
-spec fill_bg_area(etui@buffer:buffer(), etui@geometry:rect(), etui@style:color(), etui@style:color(), integer()) -> etui@buffer:buffer().
fill_bg_area(Buf, Area, Fg, Bg, Y) ->
    case Y >= (erlang:element(3, erlang:element(2, Area)) + erlang:element(3, erlang:element(3, Area))) of
        true ->
            Buf;

        false ->
            Row = etui@text:pad_right(~"", erlang:element(2, erlang:element(3, Area))),
            Buf2 = etui@buffer:set_string(Buf, {position, erlang:element(2, erlang:element(2, Area)), Y}, Row, etui@style:new(Fg, Bg, etui@style:none())),
            fill_bg_area(Buf2, Area, Fg, Bg, Y + 1)
    end.

-file("src/etui/widgets/block.gleam", 285).
-spec render_content(etui@buffer:buffer(), etui@geometry:rect(), block()) -> etui@buffer:buffer().
render_content(Buf, Area, Blk) ->
    case erlang:element(13, Blk) of
        false ->
            etui@buffer:clear(Buf, Area);

        true ->
            fill_bg_area(Buf, Area, erlang:element(11, Blk), erlang:element(12, Blk), erlang:element(3, erlang:element(2, Area)))
    end.

-file("src/etui/widgets/block.gleam", 239).
-spec render_title(etui@buffer:buffer(), etui@geometry:rect(), block()) -> etui@buffer:buffer().
render_title(Buf, Area, Blk) ->
    X0 = erlang:element(2, erlang:element(2, Area)) + 1,
    Max_width = erlang:element(2, erlang:element(3, Area)) - 2,
    case erlang:element(4, Blk) of
        [_ | _] ->
            Y = case erlang:element(5, Blk) of
                top ->
                    erlang:element(3, erlang:element(2, Area));

                bottom ->
                    etui@geometry:bottom(Area) - 1
            end,
            Line = etui@span:line_aligned(erlang:element(4, Blk), erlang:element(6, Blk)),
            etui@span:render_line(Buf, {position, X0, Y}, Line, Max_width);

        [] ->
            case erlang:element(3, Blk) of
                ~"" ->
                    Buf;

                Title ->
                    Title_width = etui@text:cell_width(Title),
                    T = case Title_width > Max_width of
                        true ->
                            etui@text:truncate(Title, Max_width, ~"…");

                        false ->
                            Title
                    end,
                    T_width = etui@text:cell_width(T),
                    X_offset = case erlang:element(6, Blk) of
                        left ->
                            0;

                        right ->
                            gleam@int:max(0, Max_width - T_width);

                        center ->
                            gleam@int:max(0, (Max_width - T_width) div 2)
                    end,
                    Y@1 = case erlang:element(5, Blk) of
                        top ->
                            erlang:element(3, erlang:element(2, Area));

                        bottom ->
                            etui@geometry:bottom(Area) - 1
                    end,
                    etui@buffer:set_string(Buf, {position, X0 + X_offset, Y@1}, T, etui@style:new(erlang:element(11, Blk), erlang:element(12, Blk), etui@style:none()))
            end
    end.

-file("src/etui/widgets/block.gleam", 381).
-spec draw_vertical_line(etui@buffer:buffer(), integer(), integer(), integer(), etui@buffer:cell()) -> etui@buffer:buffer().
draw_vertical_line(Buf, X, Y_start, Y_end, Cell) ->
    case Y_start > Y_end of
        true ->
            Buf;

        false ->
            Buf_new = etui@buffer:set_cell(Buf, {position, X, Y_start}, Cell),
            draw_vertical_line(Buf_new, X, Y_start + 1, Y_end, Cell)
    end.

-file("src/etui/widgets/block.gleam", 364).
-spec draw_horizontal_line(etui@buffer:buffer(), integer(), integer(), integer(), etui@buffer:cell()) -> etui@buffer:buffer().
draw_horizontal_line(Buf, X_start, X_end, Y, Cell) ->
    case X_start > X_end of
        true ->
            Buf;

        false ->
            Buf_new = etui@buffer:set_cell(Buf, {position, X_start, Y}, Cell),
            draw_horizontal_line(Buf_new, X_start + 1, X_end, Y, Cell)
    end.

-file("src/etui/widgets/block.gleam", 149).
-spec render_bordered(etui@buffer:buffer(), etui@geometry:rect(), block(), binary(), binary(), binary(), binary(), binary(), binary()) -> etui@buffer:buffer().
render_bordered(Buf, Area, Blk, Border_h, Border_v, Corner_tl, Corner_tr, Corner_bl, Corner_br) ->
    Width = erlang:element(2, erlang:element(3, Area)),
    Height = erlang:element(3, erlang:element(3, Area)),
    case (Width < 2) orelse (Height < 2) of
        true ->
            Buf;

        false ->
            X0 = erlang:element(2, erlang:element(2, Area)),
            Y0 = erlang:element(3, erlang:element(2, Area)),
            Y_bottom = etui@geometry:bottom(Area) - 1,
            X_right = etui@geometry:right(Area) - 1,
            Cell_border = {cell, {content, Border_h, 1}, etui@style:new(erlang:element(11, Blk), erlang:element(12, Blk), etui@style:none()), ~""},
            Buf1 = etui@buffer:set_cell(Buf, {position, X0, Y0}, {cell, {content, Corner_tl, 1}, etui@style:new(erlang:element(11, Blk), erlang:element(12, Blk), etui@style:none()), ~""}),
            Buf2 = etui@buffer:set_cell(Buf1, {position, X_right, Y0}, {cell, {content, Corner_tr, 1}, etui@style:new(erlang:element(11, Blk), erlang:element(12, Blk), etui@style:none()), ~""}),
            Buf3 = etui@buffer:set_cell(Buf2, {position, X0, Y_bottom}, {cell, {content, Corner_bl, 1}, etui@style:new(erlang:element(11, Blk), erlang:element(12, Blk), etui@style:none()), ~""}),
            Buf4 = etui@buffer:set_cell(Buf3, {position, X_right, Y_bottom}, {cell, {content, Corner_br, 1}, etui@style:new(erlang:element(11, Blk), erlang:element(12, Blk), etui@style:none()), ~""}),
            Buf5 = draw_horizontal_line(Buf4, X0 + 1, X_right - 1, Y0, Cell_border),
            Buf6 = draw_horizontal_line(Buf5, X0 + 1, X_right - 1, Y_bottom, Cell_border),
            Cell_v = {cell, {content, Border_v, 1}, etui@style:new(erlang:element(11, Blk), erlang:element(12, Blk), etui@style:none()), ~""},
            Buf7 = draw_vertical_line(Buf6, X0, Y0 + 1, Y_bottom - 1, Cell_v),
            Buf8 = draw_vertical_line(Buf7, X_right, Y0 + 1, Y_bottom - 1, Cell_v),
            Buf9 = render_title(Buf8, Area, Blk),
            render_content(Buf9, inner_area(Area, Blk), Blk)
    end.

-file("src/etui/widgets/block.gleam", 136).
-spec render(etui@buffer:buffer(), etui@geometry:rect(), block()) -> etui@buffer:buffer().
-doc(~" Render block into buffer at given area.").
render(Buf, Area, Blk) ->
    case erlang:element(2, Blk) of
        none ->
            render_content(Buf, Area, Blk);

        single ->
            render_bordered(Buf, Area, Blk, ~"─", ~"│", ~"┌", ~"┐", ~"└", ~"┘");

        double ->
            render_bordered(Buf, Area, Blk, ~"═", ~"║", ~"╔", ~"╗", ~"╚", ~"╝");

        rounded ->
            render_bordered(Buf, Area, Blk, ~"─", ~"│", ~"╭", ~"╮", ~"╰", ~"╯")
    end.

-file("src/etui/widgets/block.gleam", 328).
-spec inner(etui@geometry:rect(), block()) -> etui@geometry:rect().
-doc(~" Inner area (content region) of a block, accounting for border and padding.

 Use this to get the Rect to pass to child widgets:

 ```gleam
 let b = block.block_new() |> block.with_border(block.Single)
 block.render(buf, area, b)
 |> paragraph.render(block.inner(area, b), p)
 ```").
inner(Area, Blk) ->
    inner_area(Area, Blk).

