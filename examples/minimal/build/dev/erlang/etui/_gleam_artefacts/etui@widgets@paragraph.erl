-module(etui@widgets@paragraph).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([paragraph_new/1, with_alignment/2, with_style/2, paragraph_new_lines/1, render_styled/3, render_text/3, render_lines_styled/3, render/3]).
-export_type([paragraph/0, span_paragraph/0]).

-type paragraph() :: {paragraph, binary(), etui@text:alignment(), etui@style:color(), etui@style:color(), etui@style:modifier()}.

-type span_paragraph() :: {span_paragraph, list(etui@span:line())}.

-file("src/etui/widgets/paragraph.gleam", 24).
-spec paragraph_new(binary()) -> paragraph().
-doc(~" New paragraph with left-aligned text and default colors.").
paragraph_new(Text) ->
    {paragraph, Text, left, default, default, etui@style:none()}.

-file("src/etui/widgets/paragraph.gleam", 35).
-spec with_alignment(paragraph(), etui@text:alignment()) -> paragraph().
-doc(~" Set text alignment (Left, Center, Right).").
with_alignment(P, Alignment) ->
    {paragraph, erlang:element(2, P), Alignment, erlang:element(4, P), erlang:element(5, P), erlang:element(6, P)}.

-file("src/etui/widgets/paragraph.gleam", 40).
-spec with_style(paragraph(), etui@style:style()) -> paragraph().
-doc(~" Apply a style (colors + modifier) to the paragraph text.").
with_style(P, S) ->
    {paragraph, erlang:element(2, P), erlang:element(3, P), erlang:element(2, S), erlang:element(3, S), erlang:element(4, S)}.

-file("src/etui/widgets/paragraph.gleam", 62).
-spec paragraph_new_lines(list(etui@span:line())) -> span_paragraph().
-doc(~" Build a `SpanParagraph` from a list of `span.Line` values.

 ```gleam
 paragraph.paragraph_new_lines([
   span.line_new([span.span_plain(\"normal \"), span.span_styled(\"bold\", style.bold_style())]),
   span.line_plain(\"second line\"),
 ])
 |> paragraph.render_lines_styled(buf, area, _)
 ```").
paragraph_new_lines(Lines) ->
    {span_paragraph, Lines}.

-file("src/etui/widgets/paragraph.gleam", 114).
-spec render_span_rows(etui@buffer:buffer(), etui@geometry:rect(), list(etui@span:line()), integer()) -> etui@buffer:buffer().
render_span_rows(Buf, Area, Lines, Row) ->
    case Lines of
        [] ->
            Buf;

        [Line | Rest] ->
            case Row >= erlang:element(3, erlang:element(3, Area)) of
                true ->
                    Buf;

                false ->
                    Pos = {position, erlang:element(2, erlang:element(2, Area)), erlang:element(3, erlang:element(2, Area)) + Row},
                    Buf2 = etui@span:render_line(Buf, Pos, Line, erlang:element(2, erlang:element(3, Area))),
                    render_span_rows(Buf2, Area, Rest, Row + 1)
            end
    end.

-file("src/etui/widgets/paragraph.gleam", 103).
-spec render_styled(etui@buffer:buffer(), etui@geometry:rect(), list(etui@span:line())) -> etui@buffer:buffer().
-doc(~" Render a list of `span.Line` values, one per row, into `area`.
 Each `Line` is drawn with per-span styles. Lines beyond area height
 are clipped; the list may be shorter than the area (remaining rows unchanged).").
render_styled(Buf, Area, Lines) ->
    case (erlang:element(2, erlang:element(3, Area)) =< 0) orelse (erlang:element(3, erlang:element(3, Area)) =< 0) of
        true ->
            Buf;

        false ->
            render_span_rows(Buf, Area, Lines, 0)
    end.

-file("src/etui/widgets/paragraph.gleam", 79).
-spec render_text(etui@buffer:buffer(), etui@geometry:rect(), etui@span:text()) -> etui@buffer:buffer().
-doc(~" Render styled text into `area`, wrapping it to the area width.

 This is the one to reach for when text has both mixed styles and enough of
 it to need reflowing. `render_styled` puts one `Line` per row and lets
 anything too wide fall off the edge; `paragraph_new` wraps but only takes a
 plain `String`, so it cannot carry styles.

 ```gleam
 span.text_new([
   span.line_new([span.span_bold(\"ERROR\"), span.span_plain(\" disk full\")]),
 ])
 |> paragraph.render_text(buf, area, _)
 ```").
render_text(Buf, Area, Content) ->
    case (erlang:element(2, erlang:element(3, Area)) =< 0) orelse (erlang:element(3, erlang:element(3, Area)) =< 0) of
        true ->
            Buf;

        false ->
            render_styled(Buf, Area, erlang:element(2, etui@span:wrap(Content, erlang:element(2, erlang:element(3, Area)))))
    end.

-file("src/etui/widgets/paragraph.gleam", 92).
-spec render_lines_styled(etui@buffer:buffer(), etui@geometry:rect(), span_paragraph()) -> etui@buffer:buffer().
-doc(~" Render a `SpanParagraph` into `area`. Lines beyond area height are clipped.
 Does not wrap: see `render_text` for that.").
render_lines_styled(Buf, Area, Para) ->
    render_styled(Buf, Area, erlang:element(2, Para)).

-file("src/etui/widgets/paragraph.gleam", 156).
-spec render_lines(etui@buffer:buffer(), etui@geometry:rect(), paragraph(), list(binary()), integer()) -> etui@buffer:buffer().
render_lines(Buf, Area, Para, Lines, Line_idx) ->
    case Lines of
        [] ->
            Buf;

        [Line | Rest] ->
            case Line_idx >= erlang:element(3, erlang:element(3, Area)) of
                true ->
                    Buf;

                false ->
                    Y = erlang:element(3, erlang:element(2, Area)) + Line_idx,
                    Aligned_line = etui@text:align(Line, erlang:element(2, erlang:element(3, Area)), erlang:element(3, Para)),
                    Buf_new = etui@buffer:set_string(Buf, {position, erlang:element(2, erlang:element(2, Area)), Y}, Aligned_line, etui@style:new(erlang:element(4, Para), erlang:element(5, Para), erlang:element(6, Para))),
                    render_lines(Buf_new, Area, Para, Rest, Line_idx + 1)
            end
    end.

-file("src/etui/widgets/paragraph.gleam", 140).
-spec render(etui@buffer:buffer(), etui@geometry:rect(), paragraph()) -> etui@buffer:buffer().
-doc(~" Render paragraph into buffer at `area`. Word-wraps to area width.
 Rows beyond area height are clipped. Short lines are padded to area width.").
render(Buf, Area, Para) ->
    case (erlang:element(2, erlang:element(3, Area)) =< 0) orelse (erlang:element(3, erlang:element(3, Area)) =< 0) of
        true ->
            Buf;

        false ->
            Lines = etui@text:wrap(erlang:element(2, Para), erlang:element(2, erlang:element(3, Area))),
            render_lines(Buf, Area, Para, Lines, 0)
    end.

