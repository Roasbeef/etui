-module(etui_buffer_array_ffi).
-export([new/2, get/2, set/3, fill_string/6, fill_all_rows/6,
         draft/1, draft_set/3, draft_get/2, commit/1, same/2]).
-on_load(init_module/0).

%% Pre-allocate {content, <<B>>, 1} tuples for all 256 bytes on module load.
%% fill_bin receives the table once per row call and uses element/2 (O(1), no alloc)
%% instead of constructing a new Content tuple per character.
init_module() ->
    T = list_to_tuple([{content, <<B>>, 1} || B <- lists:seq(0, 255)]),
    persistent_term:put(etui_ascii_content_table, T),
    ok.

%% Fixed-size array with a default value for unset indices.
%% Erlang `array` is a sparse persistent trie; get/set are O(log10 N)
%% with tiny constants, much cheaper than dict for integer-keyed dense data.

%% Cheap identity test: true when the two are the same physical term, false
%% when they merely might be equal. Callers fall back to a structural compare.
%% erts_debug:same/2 is the pointer comparison; =:= would walk two equal-but-
%% distinct terms in full, which is the work this call exists to avoid.
same(A, B) -> erts_debug:same(A, B).

new(Size, Default) ->
    array:new(Size, [{default, Default}]).

get(Index, Arr) ->
    array:get(Index, Arr).

set(Index, Value, Arr) ->
    array:set(Index, Value, Arr).

%% Batched writes. Erlang's array is already a persistent trie, so a draft is
%% the array itself and these are all identity or a plain set; the distinction
%% exists for the JavaScript side, where a naive copy-on-write set made a full
%% buffer fill quadratic.
draft(Arr) -> Arr.
draft_set(Index, Value, Arr) -> array:set(Index, Value, Arr).
draft_get(Index, Arr) -> array:get(Index, Arr).
commit(Arr) -> Arr.

%% Fill cells in Arr[StartIdx..MaxIdx) from a UTF-8 binary string.
%% Cell tuples are constructed directly, avoids Gleam list/fold overhead.
%%
%% Cell format mirrors buffer.gleam's Gleam types:
%%   {cell, {content, Symbol, Width}, Style, Link}, normal cell
%%   {cell, continuation, Style, <<>>}, wide-char trailer
%% The style is an opaque term here: it arrives already resolved from Gleam
%% and is only ever copied into cells, so this module never looks inside it.
fill_string(Arr, StartIdx, MaxIdx, Bin, St, Link) ->
    T = persistent_term:get(etui_ascii_content_table),
    fill_bin(Arr, StartIdx, MaxIdx, Bin, St, Link, T).

fill_bin(Arr, Idx, MaxIdx, _, _, _, _) when Idx >= MaxIdx ->
    Arr;
fill_bin(Arr, _, _, <<>>, _, _, _) ->
    Arr;
%% ASCII printable fast path: cached Content tuple, single Cell alloc per char
fill_bin(Arr, Idx, MaxIdx, <<B, Rest/binary>>, St, Link, T)
        when B >= 16#20, B < 16#7F ->
    Content = element(B + 1, T),
    Cell = {cell, Content, St, Link},
    fill_bin(array:set(Idx, Cell, Arr), Idx + 1, MaxIdx, Rest, St, Link, T);
%% Skip non-printable ASCII (control chars, DEL)
fill_bin(Arr, Idx, MaxIdx, <<B, Rest/binary>>, St, Link, T) when B < 16#20 ->
    fill_bin(Arr, Idx, MaxIdx, Rest, St, Link, T);
fill_bin(Arr, Idx, MaxIdx, <<16#7F, Rest/binary>>, St, Link, T) ->
    fill_bin(Arr, Idx, MaxIdx, Rest, St, Link, T);
%% Non-ASCII: grapheme cluster segmentation + East Asian width.
%% string:next_grapheme/1 returns [Codepoint|Rest] (single cp)
%% or [[Cp,...]|Rest] (ZWJ sequence / multi-cp cluster).
fill_bin(Arr, Idx, MaxIdx, Bin, St, Link, T) ->
    case string:next_grapheme(Bin) of
        [] -> Arr;
        [G | Rest] ->
            {GBin, W} = grapheme_parts(G),
            fill_grapheme(Arr, Idx, MaxIdx, Rest, GBin, W, St, Link, T)
    end.

%% Write one grapheme cluster at Idx.
%%
%% A wide grapheme needs two columns. If only one is left before MaxIdx the
%% cell is left blank: writing the glyph anyway made it overflow the clip
%% boundary and shift everything to its right.
fill_grapheme(Arr, Idx, MaxIdx, Rest, _GBin, W, St, Link, T)
        when W >= 2, Idx + 1 >= MaxIdx ->
    fill_bin(Arr, Idx + 1, MaxIdx, Rest, St, Link, T);
fill_grapheme(Arr, Idx, MaxIdx, Rest, GBin, W, St, Link, T)
        when W >= 2 ->
    Cell = {cell, {content, GBin, W}, St, Link},
    Cont = {cell, continuation, St, <<>>},
    Arr2 = array:set(Idx + 1, Cont, array:set(Idx, Cell, Arr)),
    fill_bin(Arr2, Idx + 2, MaxIdx, Rest, St, Link, T);
fill_grapheme(Arr, Idx, MaxIdx, Rest, GBin, W, St, Link, T) ->
    Cell = {cell, {content, GBin, W}, St, Link},
    fill_bin(array:set(Idx, Cell, Arr), Idx + 1, MaxIdx, Rest, St, Link, T).

%% Fill an entire Width×Height buffer from scratch using array:from_list/2.
%% Each row gets the same Bin text. Builds cells as a reversed flat list,
%% reverses once at the end, then constructs the trie in one shot.
%% 3× faster than 60 sequential fill_string calls which rebuild the trie per row.
fill_all_rows(Width, Height, Bin, St, Link, Default) ->
    T = persistent_term:get(etui_ascii_content_table),
    RevCells = build_buffer_rev(Width, Height, 0, Bin, St, Link, T, Default, []),
    array:from_list(lists:reverse(RevCells), Default).

build_buffer_rev(_, Height, Row, _, _, _, _, _, RevAcc) when Row >= Height ->
    RevAcc;
build_buffer_rev(Width, Height, Row, Bin, St, Link, T, Default, RevAcc) ->
    RevAcc2 = build_row_rev(Width, 0, Bin, St, Link, T, Default, RevAcc),
    build_buffer_rev(Width, Height, Row + 1, Bin, St, Link, T, Default, RevAcc2).

%% Produces exactly Width cells, padding with Default if Bin is exhausted.
%% Mirrors fill_bin/7 clause for clause: ASCII fast path, control characters
%% consume no cell, everything else goes through grapheme segmentation.
build_row_rev(Width, Col, _, _, _, _, _Default, RevAcc) when Col >= Width ->
    RevAcc;
build_row_rev(Width, Col, <<>>, _St, _Link, _T, Default, RevAcc) ->
    fill_rev(Width - Col, Default, RevAcc);
%% ASCII printable fast path: cached Content tuple, single Cell alloc per char.
build_row_rev(Width, Col, <<B, Rest/binary>>, St, Link, T, Default, RevAcc)
        when B >= 16#20, B < 16#7F ->
    Content = element(B + 1, T),
    Cell = {cell, Content, St, Link},
    build_row_rev(Width, Col + 1, Rest, St, Link, T, Default, [Cell | RevAcc]);
%% Control characters and DEL occupy no cell.
build_row_rev(Width, Col, <<B, Rest/binary>>, St, Link, T, Default, RevAcc)
        when B < 16#20; B =:= 16#7F ->
    build_row_rev(Width, Col, Rest, St, Link, T, Default, RevAcc);
%% Non-ASCII: grapheme cluster segmentation + East Asian width.
%% Dropping these (the previous catch-all did) silently deleted every CJK and
%% emoji character from a filled buffer, and diverged from the JS backend.
build_row_rev(Width, Col, Bin, St, Link, T, Default, RevAcc) ->
    case string:next_grapheme(Bin) of
        [] ->
            fill_rev(Width - Col, Default, RevAcc);
        [G | Rest] ->
            {GBin, GW} = grapheme_parts(G),
            case GW of
                W when W >= 2, Col + 1 >= Width ->
                    %% No room for the trailing half. Emit a blank rather than
                    %% a wide glyph that would overflow the row.
                    build_row_rev(Width, Col + 1, Rest, St, Link, T,
                                  Default, [Default | RevAcc]);
                W when W >= 2 ->
                    Cell = {cell, {content, GBin, W}, St, Link},
                    Cont = {cell, continuation, St, <<>>},
                    build_row_rev(Width, Col + 2, Rest, St, Link, T,
                                  Default, [Cont, Cell | RevAcc]);
                W ->
                    Cell = {cell, {content, GBin, W}, St, Link},
                    build_row_rev(Width, Col + 1, Rest, St, Link, T,
                                  Default, [Cell | RevAcc])
            end
    end.

%% string:next_grapheme/1 yields a bare codepoint for a single-codepoint
%% cluster and a list for a multi-codepoint one (ZWJ sequence, flag pair).
%%
%% The width comes back with the binary rather than the first codepoint,
%% because a variation selector is the second codepoint of the cluster and
%% changes how wide the base is drawn. Handing the caller the first codepoint
%% alone lost that, and text.gleam's grapheme_cell_width/1 would then disagree
%% with what a fill actually laid out.
grapheme_parts(G) when is_integer(G) ->
    {unicode:characters_to_binary([G]), cp_width(G)};
grapheme_parts([Cp]) ->
    {unicode:characters_to_binary([Cp]), cp_width(Cp)};
grapheme_parts([Base, Next | _] = GList) ->
    {unicode:characters_to_binary(GList), presentation_width(Base, Next)}.

%% Width of Base once the codepoint after it has had its say. Mirrors
%% text.gleam's presentation_width/2: U+FE0F asks for the emoji glyph (two
%% cells), U+FE0E for the text one, and VS15 only demotes a base below
%% U+1F000, where a text glyph exists to fall back to.
presentation_width(_Base, 16#FE0F) -> 2;
presentation_width(Base, 16#FE0E) when Base < 16#1F000 -> 1;
presentation_width(Base, _Next) -> cp_width(Base).

fill_rev(0, _, Acc) -> Acc;
fill_rev(N, V, Acc) -> fill_rev(N - 1, V, [V | Acc]).

%% East Asian Width, mirrors text.gleam's codepoint_cell_width/1.
cp_width(Cp) when Cp < 16#20         -> 0;
cp_width(16#7F)                       -> 0;
cp_width(Cp) when Cp >= 16#0300,
                  Cp =< 16#036F      -> 0;  % combining diacritics
cp_width(Cp) when Cp >= 16#1160,
                  Cp =< 16#11FF      -> 0;  % Hangul medial/final combining
cp_width(Cp) when Cp >= 16#FE00,
                  Cp =< 16#FE0F      -> 0;  % variation selectors
cp_width(Cp) when Cp >= 16#E0100,
                  Cp =< 16#E01EF     -> 0;  % variation selectors ext.
cp_width(16#200B)                     -> 0;
cp_width(16#200C)                     -> 0;
cp_width(16#200D)                     -> 0;
cp_width(16#FEFF)                     -> 0;
cp_width(Cp) when Cp >= 16#1100,
                  Cp =< 16#115F      -> 2;  % Hangul Jamo initial
cp_width(Cp) when Cp >= 16#2E80,
                  Cp =< 16#303E      -> 2;  % CJK Radicals / Kangxi
cp_width(Cp) when Cp >= 16#3041,
                  Cp =< 16#33FF      -> 2;  % Hiragana/Katakana/CJK compat
cp_width(Cp) when Cp >= 16#3400,
                  Cp =< 16#4DBF      -> 2;  % CJK Extension A
cp_width(Cp) when Cp >= 16#4E00,
                  Cp =< 16#9FFF      -> 2;  % CJK Unified Ideographs
cp_width(Cp) when Cp >= 16#A000,
                  Cp =< 16#A4CF      -> 2;  % Yi
cp_width(Cp) when Cp >= 16#AC00,
                  Cp =< 16#D7A3      -> 2;  % Hangul Syllables
cp_width(Cp) when Cp >= 16#F900,
                  Cp =< 16#FAFF      -> 2;  % CJK Compatibility Ideographs
cp_width(Cp) when Cp >= 16#FE30,
                  Cp =< 16#FE4F      -> 2;  % CJK Compatibility Forms
cp_width(Cp) when Cp >= 16#FF00,
                  Cp =< 16#FF60      -> 2;  % Fullwidth Forms
cp_width(Cp) when Cp >= 16#FFE0,
                  Cp =< 16#FFE6      -> 2;  % Fullwidth Signs
cp_width(Cp) when Cp >= 16#1F1E6,
                  Cp =< 16#1F1FF     -> 2;  % Regional Indicators (flags)
%% One range per emoji block rather than one blanket 1F300..1FAFF. The blanket
%% swept in Ornamental Dingbats (1F650..1F67F), which East Asian Width calls
%% Neutral and text.gleam leaves at one cell, so a buffer filled here and a
%% width measured there disagreed by a column for those glyphs.
cp_width(Cp) when Cp >= 16#1F300,
                  Cp =< 16#1F5FF     -> 2;  % Misc Symbols and Pictographs
cp_width(Cp) when Cp >= 16#1F600,
                  Cp =< 16#1F64F     -> 2;  % Emoticons
cp_width(Cp) when Cp >= 16#1F680,
                  Cp =< 16#1F6FF     -> 2;  % Transport and Map Symbols
cp_width(Cp) when Cp >= 16#1F700,
                  Cp =< 16#1F77F     -> 2;  % Alchemical Symbols
cp_width(Cp) when Cp >= 16#1F780,
                  Cp =< 16#1F7FF     -> 2;  % Geometric Shapes Extended
cp_width(Cp) when Cp >= 16#1F800,
                  Cp =< 16#1F8FF     -> 2;  % Supplemental Arrows-C
cp_width(Cp) when Cp >= 16#1F900,
                  Cp =< 16#1F9FF     -> 2;  % Supplemental Symbols/Pictographs
cp_width(Cp) when Cp >= 16#1FA00,
                  Cp =< 16#1FAFF     -> 2;  % Symbols and Pictographs Ext-A
cp_width(Cp) when Cp >= 16#20000,
                  Cp =< 16#2FFFD     -> 2;  % CJK Extensions B–F
cp_width(Cp) when Cp >= 16#30000,
                  Cp =< 16#3FFFD     -> 2;  % CJK Extension G+
%% Emoji_Presentation=Yes members of blocks that are otherwise narrow. The
%% block cannot decide these: ☆ ★ are Ambiguous and one cell, ⚡ ✅ two. Mirrors
%% text.gleam's emoji_presentation_width/1, which carries the whole argument
%% and names the Unicode version the list came from.
%% Miscellaneous Technical.
cp_width(Cp) when Cp >= 16#231A, Cp =< 16#231B -> 2;
cp_width(Cp) when Cp >= 16#23E9, Cp =< 16#23EC -> 2;
cp_width(16#23F0)                              -> 2;
cp_width(16#23F3)                              -> 2;
%% Geometric Shapes.
cp_width(Cp) when Cp >= 16#25FD, Cp =< 16#25FE -> 2;
%% Miscellaneous Symbols.
cp_width(Cp) when Cp >= 16#2614, Cp =< 16#2615 -> 2;
cp_width(Cp) when Cp >= 16#2648, Cp =< 16#2653 -> 2;
cp_width(16#267F)                              -> 2;
cp_width(16#2693)                              -> 2;
cp_width(16#26A1)                              -> 2;
cp_width(Cp) when Cp >= 16#26AA, Cp =< 16#26AB -> 2;
cp_width(Cp) when Cp >= 16#26BD, Cp =< 16#26BE -> 2;
cp_width(Cp) when Cp >= 16#26C4, Cp =< 16#26C5 -> 2;
cp_width(16#26CE)                              -> 2;
cp_width(16#26D4)                              -> 2;
cp_width(16#26EA)                              -> 2;
cp_width(Cp) when Cp >= 16#26F2, Cp =< 16#26F3 -> 2;
cp_width(16#26F5)                              -> 2;
cp_width(16#26FA)                              -> 2;
cp_width(16#26FD)                              -> 2;
%% Dingbats.
cp_width(16#2705)                              -> 2;
cp_width(Cp) when Cp >= 16#270A, Cp =< 16#270B -> 2;
cp_width(16#2728)                              -> 2;
cp_width(16#274C)                              -> 2;
cp_width(16#274E)                              -> 2;
cp_width(Cp) when Cp >= 16#2753, Cp =< 16#2755 -> 2;
cp_width(16#2757)                              -> 2;
cp_width(Cp) when Cp >= 16#2795, Cp =< 16#2797 -> 2;
cp_width(16#27B0)                              -> 2;
cp_width(16#27BF)                              -> 2;
%% Miscellaneous Symbols and Arrows.
cp_width(Cp) when Cp >= 16#2B1B, Cp =< 16#2B1C -> 2;
cp_width(16#2B50)                              -> 2;
cp_width(16#2B55)                              -> 2;
%% Enclosed alphanumerics and ideographs.
cp_width(16#1F004)                             -> 2;
cp_width(16#1F0CF)                             -> 2;
cp_width(16#1F18E)                             -> 2;
cp_width(Cp) when Cp >= 16#1F191, Cp =< 16#1F19A -> 2;
cp_width(16#1F201)                             -> 2;
cp_width(16#1F21A)                             -> 2;
cp_width(16#1F22F)                             -> 2;
cp_width(Cp) when Cp >= 16#1F232, Cp =< 16#1F236 -> 2;
cp_width(Cp) when Cp >= 16#1F238, Cp =< 16#1F23A -> 2;
cp_width(Cp) when Cp >= 16#1F250, Cp =< 16#1F251 -> 2;
cp_width(_)                                    -> 1.
