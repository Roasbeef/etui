-module(etui@span).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([span_plain/1, span_styled/2, span_link/2, with_link/2, span_fg/2, span_bg/2, span_modifier/2, span_underline_color/2, span_width/1, line_new/1, line_plain/1, line_aligned/2, span_bold/1, span_italic/1, span_dim/1, span_underline/1, line_width/1, render_line/4, text_plain/1, text_new/1, text_height/1, wrap_line/2, wrap/2]).
-export_type([span/0, line/0, text/0, piece/0, word/0]).

-type span() :: {span, binary(), etui@style:style(), binary()}.

-type line() :: {line, list(span()), etui@text:alignment()}.

-type text() :: {text, list(line())}.

-type piece() :: {piece, binary(), span()}.

-type word() :: {word, span(), list(piece())}.

-file("src/etui/span.gleam", 55).
-spec span_plain(binary()) -> span().
-doc(~" Span with default terminal colors and no modifier.").
span_plain(Content) ->
    {span, Content, etui@style:default_style(), ~""}.

-file("src/etui/span.gleam", 60).
-spec span_styled(binary(), etui@style:style()) -> span().
-doc(~" Span with explicit style applied.").
span_styled(Content, S) ->
    {span, Content, S, ~""}.

-file("src/etui/span.gleam", 71).
-spec span_link(binary(), binary()) -> span().
-doc(~" Span with an OSC 8 clickable hyperlink.
 Terminals that support OSC 8 (iTerm2, Kitty, VTE, Windows Terminal) will
 render the text as a clickable link. Others display it as plain text.

 ```gleam
 span.span_link(\"docs.gleam.run\", \"https://docs.gleam.run\")
 ```").
span_link(Content, Uri) ->
    {span, Content, etui@style:default_style(), Uri}.

-file("src/etui/span.gleam", 76).
-spec with_link(span(), binary()) -> span().
-doc(~" Add an OSC 8 hyperlink URI to an existing span.").
with_link(Sp, Uri) ->
    {span, erlang:element(2, Sp), erlang:element(3, Sp), Uri}.

-file("src/etui/span.gleam", 81).
-spec span_fg(span(), etui@style:color()) -> span().
-doc(~" Set foreground color on a span.").
span_fg(Sp, Color) ->
    {span, erlang:element(2, Sp), etui@style:with_fg(erlang:element(3, Sp), Color), erlang:element(4, Sp)}.

-file("src/etui/span.gleam", 86).
-spec span_bg(span(), etui@style:color()) -> span().
-doc(~" Set background color on a span.").
span_bg(Sp, Color) ->
    {span, erlang:element(2, Sp), etui@style:with_bg(erlang:element(3, Sp), Color), erlang:element(4, Sp)}.

-file("src/etui/span.gleam", 91).
-spec span_modifier(span(), etui@style:modifier()) -> span().
-doc(~" Add a modifier to a span.").
span_modifier(Sp, Modifier) ->
    {span, erlang:element(2, Sp), etui@style:add_modifier(erlang:element(3, Sp), Modifier), erlang:element(4, Sp)}.

-file("src/etui/span.gleam", 96).
-spec span_underline_color(span(), etui@style:color()) -> span().
-doc(~" Colour the underline of a span independently of its text.").
span_underline_color(Sp, Color) ->
    {span, erlang:element(2, Sp), etui@style:with_underline_color(erlang:element(3, Sp), Color), erlang:element(4, Sp)}.

-file("src/etui/span.gleam", 101).
-spec span_width(span()) -> integer().
-doc(~" Total cell width of a span.").
span_width(Sp) ->
    etui@text:cell_width(erlang:element(2, Sp)).

-file("src/etui/span.gleam", 106).
-spec line_new(list(span())) -> line().
-doc(~" Line from a list of spans, left-aligned.").
line_new(Spans) ->
    {line, Spans, left}.

-file("src/etui/span.gleam", 111).
-spec line_plain(binary()) -> line().
-doc(~" Line with a single unstyled string, left-aligned.").
line_plain(Content) ->
    {line, [span_plain(Content)], left}.

-file("src/etui/span.gleam", 116).
-spec line_aligned(list(span()), etui@text:alignment()) -> line().
-doc(~" Line from spans with explicit alignment.").
line_aligned(Spans, Alignment) ->
    {line, Spans, Alignment}.

-file("src/etui/span.gleam", 121).
-spec span_bold(binary()) -> span().
-doc(~" Bold span (default colors + bold modifier).").
span_bold(Content) ->
    {span, Content, etui@style:new(default, default, etui@style:bold()), ~""}.

-file("src/etui/span.gleam", 130).
-spec span_italic(binary()) -> span().
-doc(~" Italic span (default colors + italic modifier).").
span_italic(Content) ->
    {span, Content, etui@style:new(default, default, etui@style:italic()), ~""}.

-file("src/etui/span.gleam", 139).
-spec span_dim(binary()) -> span().
-doc(~" Dim span (default colors + dim modifier).").
span_dim(Content) ->
    {span, Content, etui@style:new(default, default, etui@style:dim()), ~""}.

-file("src/etui/span.gleam", 148).
-spec span_underline(binary()) -> span().
-doc(~" Underline span (default colors + underline modifier).").
span_underline(Content) ->
    {span, Content, etui@style:new(default, default, etui@style:underline()), ~""}.

-file("src/etui/span.gleam", 157).
-spec line_width(line()) -> integer().
-doc(~" Total cell width of a line (sum of span widths).").
line_width(L) ->
    gleam@list:fold(erlang:element(2, L), 0, fun(Acc, Sp) ->
        Acc + span_width(Sp)
    end).

-file("src/etui/span.gleam", 189).
-spec render_spans(etui@buffer:buffer(), etui@geometry:position(), list(span()), integer(), integer()) -> etui@buffer:buffer().
render_spans(Buf, Pos, Spans, X, X_end) ->
    case Spans of
        [] ->
            Buf;

        [Sp | Rest] ->
            case X >= X_end of
                true ->
                    Buf;

                false ->
                    Avail = X_end - X,
                    Content = etui@text:truncate(erlang:element(2, Sp), Avail, ~""),
                    W = etui@text:cell_width(Content),
                    Buf2 = etui@buffer:set_string_linked(Buf, {position, X, erlang:element(3, Pos)}, Content, erlang:element(3, Sp), erlang:element(4, Sp)),
                    render_spans(Buf2, Pos, Rest, X + W, X_end)
            end
    end.

-file("src/etui/span.gleam", 168).
-spec render_line(etui@buffer:buffer(), etui@geometry:position(), line(), integer()) -> etui@buffer:buffer().
-doc(~" Render a line into the buffer at `pos`, clipped to `max_width` cells.
 Each span is drawn with its own fg/bg/modifier. Spans beyond max_width
 are silently dropped; a span that straddles the boundary is truncated.
 The line's `alignment` field shifts the start position within the available width.").
render_line(Buf, Pos, L, Max_width) ->
    case Max_width =< 0 of
        true ->
            Buf;

        false ->
            Content_width = line_width(L),
            Offset = case erlang:element(3, L) of
                left ->
                    0;

                right ->
                    gleam@int:max(0, Max_width - Content_width);

                center ->
                    gleam@int:max(0, (Max_width - Content_width) div 2)
            end,
            Start_x = erlang:element(2, Pos) + Offset,
            render_spans(Buf, Pos, erlang:element(2, L), Start_x, erlang:element(2, Pos) + Max_width)
    end.

-file("src/etui/span.gleam", 224).
-spec text_plain(binary()) -> text().
-doc(~" Text from a single unstyled string, split on newlines.").
text_plain(Content) ->
    {text, begin
        _pipe = Content,
        _pipe@1 = etui@text:normalise_newlines(_pipe),
        _pipe@2 = gleam@string:split(_pipe@1, ~"\n"),
        gleam@list:map(_pipe@2, fun line_plain/1)
    end}.

-file("src/etui/span.gleam", 234).
-spec text_new(list(line())) -> text().
-doc(~" Text from lines.").
text_new(Lines) ->
    {text, Lines}.

-file("src/etui/span.gleam", 239).
-spec text_height(text()) -> integer().
-doc(~" Total rows.").
text_height(T) ->
    erlang:length(erlang:element(2, T)).

-file("src/etui/span.gleam", 507).
-spec same_style(span(), span()) -> boolean().
same_style(A, B) ->
    (erlang:element(3, A) =:= erlang:element(3, B)) andalso (erlang:element(4, A) =:= erlang:element(4, B)).

-file("src/etui/span.gleam", 496).
-spec push(list(span()), binary(), span()) -> list(span()).
push(Current, Content, Proto) ->
    case Current of
        [Head | Rest] ->
            case same_style(Head, Proto) of
                true ->
                    [{span, <<(erlang:element(2, Head))/binary, Content/binary>>, erlang:element(3, Head), erlang:element(4, Head)} | Rest];

                false ->
                    [{span, Content, erlang:element(3, Proto), erlang:element(4, Proto)} | Current]
            end;

        [] ->
            [{span, Content, erlang:element(3, Proto), erlang:element(4, Proto)}]
    end.

-file("src/etui/span.gleam", 479).
-spec push_gap(list(span()), span(), integer()) -> list(span()).
push_gap(Current, Sep, Gap) ->
    case Gap of
        0 ->
            Current;

        _ ->
            push(Current, ~" ", Sep)
    end.

-file("src/etui/span.gleam", 486).
-spec flush(list(span()), etui@text:alignment(), list(line())) -> list(line()).
flush(Current, Alignment, Done) ->
    [{line, lists:reverse(Current), Alignment} | Done].

-file("src/etui/span.gleam", 519).
-spec take_cells(list(binary()), integer(), integer(), binary()) -> {binary(), binary()}.
take_cells(Graphemes, Budget, Used, Head) ->
    case Graphemes of
        [] ->
            {Head, ~""};

        [G | Rest] ->
            W = etui@text:grapheme_cell_width(G),
            case (Used + W) > Budget of
                true ->
                    {Head, erlang:list_to_binary([G | Rest])};

                false ->
                    take_cells(Rest, Budget, Used + W, <<Head/binary, G/binary>>)
            end
    end.

-file("src/etui/span.gleam", 512).
-spec split_at_width(binary(), integer()) -> {binary(), binary()}.
split_at_width(Content, Budget) ->
    case Budget =< 0 of
        true ->
            {~"", Content};

        false ->
            take_cells(gleam@string:to_graphemes(Content), Budget, 0, ~"")
    end.

-file("src/etui/span.gleam", 300).
-spec word_text(word()) -> binary().
word_text(W) ->
    erlang:list_to_binary(gleam@list:map(erlang:element(3, W), fun(P) ->
        erlang:element(2, P)
    end)).

-file("src/etui/span.gleam", 472).
-spec push_word(list(span()), word(), integer()) -> list(span()).
push_word(Current, W, Gap) ->
    Started = push_gap(Current, erlang:element(2, W), Gap),
    gleam@list:fold(erlang:element(3, W), Started, fun(Acc, Piece) ->
        push(Acc, erlang:element(2, Piece), erlang:element(3, Piece))
    end).

-file("src/etui/span.gleam", 296).
-spec word_width(word()) -> integer().
word_width(W) ->
    gleam@list:fold(erlang:element(3, W), 0, fun(Acc, P) ->
        Acc + etui@text:cell_width(erlang:element(2, P))
    end).

-file("src/etui/span.gleam", 375).
-spec pack(list(word()), integer(), etui@text:alignment(), integer(), list(span()), list(line())) -> list(line()).
pack(Words, Width, Alignment, Current_width, Current, Done) ->
    case Words of
        [] ->
            lists:reverse([{line, lists:reverse(Current), Alignment} | Done]);

        [W | Rest] ->
            This_width = word_width(W),
            Gap = case Current of
                [] ->
                    0;

                _ ->
                    1
            end,
            case ((Current_width + Gap) + This_width) =< Width of
                true ->
                    pack(Rest, Width, Alignment, (Current_width + Gap) + This_width, push_word(Current, W, Gap), Done);

                false ->
                    case This_width =< Width of
                        true ->
                            pack(Rest, Width, Alignment, This_width, push_word([], W, 0), flush(Current, Alignment, Done));

                        false ->
                            Proto = case erlang:element(3, W) of
                                [{piece, _, St} | _] ->
                                    St;

                                [] ->
                                    span_plain(~"")
                            end,
                            Flat = word_text(W),
                            {Head, Tail} = split_at_width(Flat, (Width - Current_width) - Gap),
                            case Head of
                                ~"" ->
                                    {H2, T2} = split_at_width(Flat, Width),
                                    pack([{word, erlang:element(2, W), [{piece, T2, Proto}]} | Rest], Width, Alignment, etui@text:cell_width(H2), push([], H2, Proto), flush(Current, Alignment, Done));

                                _ ->
                                    pack([{word, erlang:element(2, W), [{piece, Tail, Proto}]} | Rest], Width, Alignment, 0, [], flush(push(push_gap(Current, erlang:element(2, W), Gap), Head, Proto), Alignment, Done))
                            end
                    end
            end
    end.

-file("src/etui/span.gleam", 340).
-spec absorb(list(binary()), span(), list(piece()), span(), list(word()), boolean()) -> {list(piece()), span(), list(word())}.
absorb(Parts, Sp, Pending, Pending_sep, Done, First) ->
    case Parts of
        [] ->
            {Pending, Pending_sep, Done};

        [Part | Rest] ->
            {Carry, Carry_sep, Closed} = case First of
                true ->
                    {Pending, Pending_sep, Done};

                false ->
                    case Pending of
                        [] ->
                            {[], Sp, Done};

                        _ ->
                            {[], Sp, [{word, Pending_sep, lists:reverse(Pending)} | Done]}
                    end
            end,
            Grown = case Part of
                ~"" ->
                    Carry;

                _ ->
                    [{piece, Part, Sp} | Carry]
            end,
            absorb(Rest, Sp, Grown, Carry_sep, Closed, false)
    end.

-file("src/etui/span.gleam", 317).
-spec tokenise_loop(list(span()), list(piece()), span(), list(word())) -> {list(word()), list(piece()), span()}.
tokenise_loop(Spans, Pending, Pending_sep, Done) ->
    case Spans of
        [] ->
            {Done, Pending, Pending_sep};

        [Sp | Rest] ->
            {Next_pending, Next_sep, Next_done} = absorb(gleam@string:split(erlang:element(2, Sp), ~" "), Sp, Pending, Pending_sep, Done, true),
            tokenise_loop(Rest, Next_pending, Next_sep, Next_done)
    end.

-file("src/etui/span.gleam", 304).
-spec tokenise(list(span()), list(word())) -> list(word()).
tokenise(Spans, Acc) ->
    Blank = span_plain(~""),
    {Words, Pending, Pending_sep} = tokenise_loop(Spans, [], Blank, []),
    All = case Pending of
        [] ->
            Words;

        _ ->
            [{word, Pending_sep, lists:reverse(Pending)} | Words]
    end,
    _ = Acc,
    lists:reverse(All).

-file("src/etui/span.gleam", 265).
-spec wrap_line(line(), integer()) -> list(line()).
-doc(~" Wrap one line into as many as it takes.

 Words are the unit, as in `text.wrap`, and a word wider than the line is
 broken across rows rather than left to overflow. A word never loses its
 style by being moved to another row, which is the whole point: the styles
 travel with the words rather than with the columns they happened to be in.").
wrap_line(L, Width) ->
    case Width =< 0 of
        true ->
            [];

        false ->
            case tokenise(erlang:element(2, L), []) of
                [] ->
                    [{line, [], erlang:element(3, L)}];

                Words ->
                    pack(Words, Width, erlang:element(3, L), 0, [], [])
            end
    end.

-file("src/etui/span.gleam", 252).
-spec wrap(text(), integer()) -> text().
-doc(~" Wrap every line to `width` cells, keeping each span's style.

 ```gleam
 span.line_new([span.span_bold(\"ERROR\"), span.span_plain(\" disk full\")])
 |> span.text_new([_])
 |> span.wrap(12)
 // ERROR disk   <- still bold
 // full
 ```").
wrap(T, Width) ->
    case Width =< 0 of
        true ->
            {text, []};

        false ->
            {text, gleam@list:flat_map(erlang:element(2, T), fun(_capture) ->
                wrap_line(_capture, Width)
            end)}
    end.

