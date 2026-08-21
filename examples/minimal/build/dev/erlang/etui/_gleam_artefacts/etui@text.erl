-module(etui@text).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([graphemes/1, codepoint_cell_width/1, grapheme_cell_width/1, cell_width/1, truncate/3, expand_tabs/2, normalise_newlines/1, wrap/2, pad_right/2, pad_left/2, align/3, strip_ansi/1]).
-export_type([alignment/0, strip_state/0]).

-type alignment() :: left | center | right.

-type strip_state() :: plain | esc_seen | csi_body | osc_body | osc_esc_seen.

-file("src/etui/text.gleam", 33).
-spec graphemes(binary()) -> list(binary()).
-doc(~" Split a string into grapheme clusters (UAX #29, via Erlang Unicode).

 Each element is one user-perceived character: a base letter, a ZWJ
 sequence, a flag pair, an emoji with modifiers, etc.

 ```gleam
 graphemes(\"café\") // [\"c\", \"a\", \"f\", \"é\"]
 graphemes(\"👨‍👩‍👧‍👦\") // [\"👨‍👩‍👧‍👦\"], one cluster
 ```").
graphemes(S) ->
    gleam@string:to_graphemes(S).

-file("src/etui/text.gleam", 58).
-spec codepoint_cell_width(integer()) -> integer().
-doc(~" Cell width of a single Unicode codepoint.
 Returns 0 for control / combining / zero-width, 2 for wide (CJK / emoji /
 fullwidth), 1 otherwise.").
codepoint_cell_width(Cp) ->
    case Cp of
        N when N < 32 ->
            0;

        127 ->
            0;

        N@1 when (N@1 >= 768) andalso (N@1 =< 879) ->
            0;

        N@2 when (N@2 >= 4448) andalso (N@2 =< 4607) ->
            0;

        N@3 when (N@3 >= 65024) andalso (N@3 =< 65039) ->
            0;

        N@4 when (N@4 >= 917760) andalso (N@4 =< 917999) ->
            0;

        8203 ->
            0;

        8204 ->
            0;

        8205 ->
            0;

        65279 ->
            0;

        N@5 when (N@5 >= 4352) andalso (N@5 =< 4447) ->
            2;

        N@6 when (N@6 >= 11904) andalso (N@6 =< 12350) ->
            2;

        N@7 when (N@7 >= 12353) andalso (N@7 =< 13311) ->
            2;

        N@8 when (N@8 >= 13312) andalso (N@8 =< 19903) ->
            2;

        N@9 when (N@9 >= 19968) andalso (N@9 =< 40959) ->
            2;

        N@10 when (N@10 >= 40960) andalso (N@10 =< 42191) ->
            2;

        N@11 when (N@11 >= 44032) andalso (N@11 =< 55203) ->
            2;

        N@12 when (N@12 >= 63744) andalso (N@12 =< 64255) ->
            2;

        N@13 when (N@13 >= 65072) andalso (N@13 =< 65103) ->
            2;

        N@14 when (N@14 >= 65280) andalso (N@14 =< 65376) ->
            2;

        N@15 when (N@15 >= 65504) andalso (N@15 =< 65510) ->
            2;

        N@16 when (N@16 >= 127462) andalso (N@16 =< 127487) ->
            2;

        N@17 when (N@17 >= 127744) andalso (N@17 =< 128511) ->
            2;

        N@18 when (N@18 >= 128512) andalso (N@18 =< 128591) ->
            2;

        N@19 when (N@19 >= 128640) andalso (N@19 =< 128767) ->
            2;

        N@20 when (N@20 >= 128768) andalso (N@20 =< 128895) ->
            2;

        N@21 when (N@21 >= 128896) andalso (N@21 =< 129023) ->
            2;

        N@22 when (N@22 >= 129024) andalso (N@22 =< 129279) ->
            2;

        N@23 when (N@23 >= 129280) andalso (N@23 =< 129535) ->
            2;

        N@24 when (N@24 >= 129536) andalso (N@24 =< 129791) ->
            2;

        N@25 when (N@25 >= 131072) andalso (N@25 =< 196605) ->
            2;

        N@26 when (N@26 >= 196608) andalso (N@26 =< 262141) ->
            2;

        _ ->
            1
    end.

-file("src/etui/text.gleam", 48).
-spec grapheme_cell_width(binary()) -> integer().
-doc(~" Cell width of a single grapheme cluster.
 Uses the first codepoint's East Asian Width / emoji classification.
 Subsequent codepoints in a grapheme (combining, ZWJ, variation selectors)
 contribute 0, so the first determines the visible cell count.").
grapheme_cell_width(G) ->
    case gleam@string:to_utf_codepoints(G) of
        [] ->
            0;

        [Cp | _] ->
            codepoint_cell_width(gleam_stdlib:identity(Cp))
    end.

-file("src/etui/text.gleam", 38).
-spec cell_width(binary()) -> integer().
-doc(~" Cell width of a string (sum of grapheme widths).").
cell_width(S) ->
    _pipe = S,
    _pipe@1 = gleam@string:to_graphemes(_pipe),
    gleam@list:fold(_pipe@1, 0, fun(Acc, G) ->
        Acc + grapheme_cell_width(G)
    end).

-file("src/etui/text.gleam", 159).
-spec take_prefix(list(binary()), integer(), integer(), binary()) -> binary().
take_prefix(Graphemes, Available, Width, Acc) ->
    case Graphemes of
        [] ->
            Acc;

        [G | Rest] ->
            G_width = grapheme_cell_width(G),
            case (Width + G_width) =< Available of
                true ->
                    take_prefix(Rest, Available, Width + G_width, <<Acc/binary, G/binary>>);

                false ->
                    Acc
            end
    end.

-file("src/etui/text.gleam", 141).
-spec truncate(binary(), integer(), binary()) -> binary().
-doc(~" Truncate to max_width cells. Appends ellipsis only if truncation occurs.
 The ellipsis itself counts toward the budget.").
truncate(S, Max_width, Ellipsis) ->
    case Max_width of
        W when W =< 0 ->
            ~"";

        _ ->
            S_width = cell_width(S),
            case S_width =< Max_width of
                true ->
                    S;

                false ->
                    Ellipsis_width = cell_width(Ellipsis),
                    Available = gleam@int:max(0, Max_width - Ellipsis_width),
                    Gs = gleam@string:to_graphemes(S),
                    <<(take_prefix(Gs, Available, 0, ~""))/binary, Ellipsis/binary>>
            end
    end.

-file("src/etui/text.gleam", 305).
-spec join_words(list(binary())) -> binary().
join_words(Rev_words) ->
    gleam@string:join(lists:reverse(Rev_words), ~" ").

-file("src/etui/text.gleam", 348).
-spec join_rev(list(binary())) -> binary().
join_rev(Rev_pieces) ->
    erlang:list_to_binary(lists:reverse(Rev_pieces)).

-file("src/etui/text.gleam", 319).
-spec hard_break_acc(list(binary()), integer(), integer(), list(binary()), list(binary())) -> list(binary()).
hard_break_acc(Gs, Max_width, Curr_w, Rev_curr, Rev_acc) ->
    case Gs of
        [] ->
            case Rev_curr of
                [] ->
                    lists:reverse(Rev_acc);

                _ ->
                    lists:reverse([join_rev(Rev_curr) | Rev_acc])
            end;

        [G | Rest] ->
            Gw = grapheme_cell_width(G),
            case (Curr_w > 0) andalso ((Curr_w + Gw) > Max_width) of
                true ->
                    hard_break_acc(Rest, Max_width, Gw, [G], [join_rev(Rev_curr) | Rev_acc]);

                false ->
                    hard_break_acc(Rest, Max_width, Curr_w + Gw, [G | Rev_curr], Rev_acc)
            end
    end.

-file("src/etui/text.gleam", 315).
-spec hard_break_word(binary(), integer()) -> list(binary()).
hard_break_word(S, Max_width) ->
    hard_break_acc(gleam@string:to_graphemes(S), Max_width, 0, [], []).

-file("src/etui/text.gleam", 259).
-spec wrap_para_words(binary(), integer()) -> list(binary()).
wrap_para_words(S, Max_width) ->
    {Rev_lines, Rev_current, _} = gleam@list:fold(gleam@string:split(S, ~" "), {[], [], 0}, fun(Acc, Word) ->
        {Lines, Current, Width} = Acc,
        Word_width = cell_width(Word),
        Gap = case Current of
            [] ->
                0;

            _ ->
                1
        end,
        case ((Width + Gap) + Word_width) =< Max_width of
            true ->
                {Lines, [Word | Current], (Width + Gap) + Word_width};

            false ->
                Closed = case Current of
                    [] ->
                        Lines;

                    _ ->
                        [join_words(Current) | Lines]
                end,
                case Word_width =< Max_width of
                    true ->
                        {Closed, [Word], Word_width};

                    false ->
                        case lists:reverse(hard_break_word(Word, Max_width)) of
                            [] ->
                                {Closed, [], 0};

                            [Last | Rest_rev] ->
                                {lists:append(Rest_rev, Closed), [Last], cell_width(Last)}
                        end
                end
        end
    end),
    All_rev = case Rev_current of
        [] ->
            Rev_lines;

        _ ->
            [join_words(Rev_current) | Rev_lines]
    end,
    lists:reverse(All_rev).

-file("src/etui/text.gleam", 251).
-spec wrap_para(binary(), integer()) -> list(binary()).
wrap_para(S, Max_width) ->
    case S of
        ~"" ->
            [~""];

        _ ->
            wrap_para_words(S, Max_width)
    end.

-file("src/etui/text.gleam", 227).
-spec expand_tabs_loop(list(binary()), integer(), integer(), list(binary())) -> binary().
expand_tabs_loop(Gs, Tab_width, Col, Rev_acc) ->
    case Gs of
        [] ->
            erlang:list_to_binary(lists:reverse(Rev_acc));

        [~"\t" | Rest] ->
            Pad = Tab_width - case Tab_width of
                0 ->
                    0;

                _value ->
                    Col rem _value
            end,
            expand_tabs_loop(Rest, Tab_width, Col + Pad, [gleam@string:repeat(~" ", Pad) | Rev_acc]);

        [~"\n" | Rest@1] ->
            expand_tabs_loop(Rest@1, Tab_width, 0, [~"\n" | Rev_acc]);

        [G | Rest@2] ->
            expand_tabs_loop(Rest@2, Tab_width, Col + grapheme_cell_width(G), [G | Rev_acc])
    end.

-file("src/etui/text.gleam", 216).
-spec expand_tabs(binary(), integer()) -> binary().
-doc(~" Expand tab characters to spaces, advancing to the next multiple of
 `tab_width` cells. Newlines reset the column counter.

 ```gleam
 text.expand_tabs(\"a\\tb\", 4)  // \"a   b\"
 ```").
expand_tabs(S, Tab_width) ->
    case gleam_stdlib:contains_string(S, ~"\t") of
        false ->
            S;

        true ->
            expand_tabs_loop(gleam@string:to_graphemes(S), gleam@int:max(1, Tab_width), 0, [])
    end.

-file("src/etui/text.gleam", 204).
-spec normalise_newlines(binary()) -> binary().
-doc(~" Normalise `\\r\\n` and lone `\\r` to `\\n`.

 No `string.contains(s, \"\\r\")` fast path: `\\r\\n` is a single grapheme
 cluster, so `contains` reports False for a `\\r` that is followed by `\\n`,
 which is exactly the case this needs to catch.").
normalise_newlines(S) ->
    _pipe = S,
    _pipe@1 = gleam@string:replace(_pipe, ~"\r\n", ~"\n"),
    gleam@string:replace(_pipe@1, ~"\r", ~"\n").

-file("src/etui/text.gleam", 187).
-spec wrap(binary(), integer()) -> list(binary()).
-doc(~" Word-wrap to max_width cells.

 Line endings are normalised first: `\\r\\n` and lone `\\r` both become `\\n`.
 A raw `\\r` left in the output would occupy zero cells and desynchronise
 every position after it.

 Tabs are expanded to spaces at 8-column tab stops before wrapping, so a
 tab never reaches the buffer (control characters are dropped there).

 Returns a list of lines, each at most `max_width` cells wide.").
wrap(S, Max_width) ->
    case Max_width of
        W when W =< 0 ->
            [];

        _ ->
            _pipe = S,
            _pipe@1 = normalise_newlines(_pipe),
            _pipe@2 = expand_tabs(_pipe@1, 8),
            _pipe@3 = gleam@string:split(_pipe@2, ~"\n"),
            gleam@list:flat_map(_pipe@3, fun(Para) ->
                wrap_para(Para, Max_width)
            end)
    end.

-file("src/etui/text.gleam", 353).
-spec pad_right(binary(), integer()) -> binary().
-doc(~" Pad right with spaces to reach `width` cells. Cell-aware.").
pad_right(S, Width) ->
    Cw = cell_width(S),
    case Cw >= Width of
        true ->
            S;

        false ->
            <<S/binary, (gleam@string:repeat(~" ", Width - Cw))/binary>>
    end.

-file("src/etui/text.gleam", 362).
-spec pad_left(binary(), integer()) -> binary().
-doc(~" Pad left with spaces to reach `width` cells. Cell-aware.").
pad_left(S, Width) ->
    Cw = cell_width(S),
    case Cw >= Width of
        true ->
            S;

        false ->
            <<(gleam@string:repeat(~" ", Width - Cw))/binary, S/binary>>
    end.

-file("src/etui/text.gleam", 371).
-spec align(binary(), integer(), alignment()) -> binary().
-doc(~" Align left/center/right within `width` cells. Cell-aware.").
align(S, Width, Alignment) ->
    case Alignment of
        left ->
            pad_right(S, Width);

        right ->
            pad_left(S, Width);

        center ->
            Cw = cell_width(S),
            case Cw >= Width of
                true ->
                    S;

                false ->
                    Total = Width - Cw,
                    Left = Total div 2,
                    Right = Total - Left,
                    <<<<(gleam@string:repeat(~" ", Left))/binary, S/binary>>/binary, (gleam@string:repeat(~" ", Right))/binary>>
            end
    end.

-file("src/etui/text.gleam", 437).
-spec is_csi_final(binary()) -> boolean().
is_csi_final(G) ->
    case gleam@string:to_utf_codepoints(G) of
        [Cp | _] ->
            N = gleam_stdlib:identity(Cp),
            (N >= 64) andalso (N =< 126);

        [] ->
            false
    end.

-file("src/etui/text.gleam", 407).
-spec strip_loop(list(binary()), binary(), strip_state()) -> binary().
strip_loop(Gs, Acc, State) ->
    case Gs of
        [] ->
            Acc;

        [G | Rest] ->
            {New_acc, New_state} = case {State, G} of
                {plain, ~"\x{001B}"} ->
                    {Acc, esc_seen};

                {plain, _} ->
                    {<<Acc/binary, G/binary>>, plain};

                {esc_seen, ~"["} ->
                    {Acc, csi_body};

                {esc_seen, ~"]"} ->
                    {Acc, osc_body};

                {esc_seen, _} ->
                    {Acc, plain};

                {csi_body, C} ->
                    case is_csi_final(C) of
                        true ->
                            {Acc, plain};

                        false ->
                            {Acc, csi_body}
                    end;

                {osc_body, ~"\x{0007}"} ->
                    {Acc, plain};

                {osc_body, ~"\x{001B}"} ->
                    {Acc, osc_esc_seen};

                {osc_body, _} ->
                    {Acc, osc_body};

                {osc_esc_seen, ~"\\"} ->
                    {Acc, plain};

                {osc_esc_seen, _} ->
                    {Acc, osc_body}
            end,
            strip_loop(Rest, New_acc, New_state)
    end.

-file("src/etui/text.gleam", 395).
-spec strip_ansi(binary()) -> binary().
-doc(~" Strip ANSI escape sequences. Handles CSI (`\\e[…<final>`) and OSC
 (`\\e]…ST`/`\\e]…BEL`) sequences.").
strip_ansi(S) ->
    strip_loop(gleam@string:to_graphemes(S), ~"", plain).

