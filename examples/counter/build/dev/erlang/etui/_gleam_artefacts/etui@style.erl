-module(etui@style).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([none/0, bold/0, dim/0, italic/0, underline/0, blink/0, reverse/0, strikethrough/0, hidden/0, rapid_blink/0, add/2, remove/2, has/2, is_none/1, modifier_equal/2, default_style/0, new/3, with_fg/2, with_bg/2, with_modifier/2, with_underline_color/2, bold_style/0, reversed/0, italic_style/0, dim_style/0, underline_style/0, add_modifier/2, remove_modifier/2, color_from_hex/1, patch/2, ansi_fg/1, ansi_bg/1, ansi_underline_color/1, resolve/1, ansi_modifier/1, ansi_reset/0]).
-export_type([color/0, modifier/0, style/0]).

-type color() :: default | {indexed, integer()} | {rgb, integer(), integer(), integer()}.

-opaque modifier() :: {modifier, integer()}.

-type style() :: {style, color(), color(), modifier(), modifier(), color()}.

-file("src/etui/style.gleam", 27).
-spec none() -> modifier().
-doc(~" No modifiers active.").
none() ->
    {modifier, 0}.

-file("src/etui/style.gleam", 32).
-spec bold() -> modifier().
-doc(~" Bold / increased intensity.").
bold() ->
    {modifier, 1}.

-file("src/etui/style.gleam", 37).
-spec dim() -> modifier().
-doc(~" Dim / decreased intensity.").
dim() ->
    {modifier, 2}.

-file("src/etui/style.gleam", 42).
-spec italic() -> modifier().
-doc(~" Italic text.").
italic() ->
    {modifier, 4}.

-file("src/etui/style.gleam", 47).
-spec underline() -> modifier().
-doc(~" Underline.").
underline() ->
    {modifier, 8}.

-file("src/etui/style.gleam", 52).
-spec blink() -> modifier().
-doc(~" Blinking text (terminal support varies).").
blink() ->
    {modifier, 16}.

-file("src/etui/style.gleam", 57).
-spec reverse() -> modifier().
-doc(~" Swap foreground and background colors.").
reverse() ->
    {modifier, 32}.

-file("src/etui/style.gleam", 62).
-spec strikethrough() -> modifier().
-doc(~" Strikethrough.").
strikethrough() ->
    {modifier, 64}.

-file("src/etui/style.gleam", 68).
-spec hidden() -> modifier().
-doc(~" Hidden text: the terminal reserves the cells but draws nothing (SGR 8).
 Useful for password fields that must keep their layout.").
hidden() ->
    {modifier, 128}.

-file("src/etui/style.gleam", 74).
-spec rapid_blink() -> modifier().
-doc(~" Rapid blink (SGR 6). Support is rarer than `blink`, which is SGR 5; a
 terminal that does not know it usually falls back to the slow one.").
rapid_blink() ->
    {modifier, 256}.

-file("src/etui/style.gleam", 82).
-spec add(modifier(), modifier()) -> modifier().
-doc(~" Combine two modifiers (bitwise OR).").
add(A, B) ->
    {modifier, erlang:'bor'(erlang:element(2, A), erlang:element(2, B))}.

-file("src/etui/style.gleam", 87).
-spec remove(modifier(), modifier()) -> modifier().
-doc(~" Remove modifier bits from `a` that are set in `b`.").
remove(A, B) ->
    {modifier, erlang:'band'(erlang:element(2, A), erlang:'bnot'(erlang:element(2, B)))}.

-file("src/etui/style.gleam", 92).
-spec has(modifier(), modifier()) -> boolean().
-doc(~" Check if `flag` bits are set in `m`.").
has(M, Flag) ->
    erlang:'band'(erlang:element(2, M), erlang:element(2, Flag)) /= 0.

-file("src/etui/style.gleam", 97).
-spec is_none(modifier()) -> boolean().
-doc(~" True when no modifier bits are set.").
is_none(M) ->
    erlang:element(2, M) =:= 0.

-file("src/etui/style.gleam", 102).
-spec modifier_equal(modifier(), modifier()) -> boolean().
-doc(~" Structural equality for modifiers.").
modifier_equal(A, B) ->
    erlang:element(2, A) =:= erlang:element(2, B).

-file("src/etui/style.gleam", 137).
-spec default_style() -> style().
-doc(~" Default style: terminal colors, no modifiers.").
default_style() ->
    {style, default, default, none(), none(), default}.

-file("src/etui/style.gleam", 150).
-spec new(color(), color(), modifier()) -> style().
-doc(~" A style from the three things most call sites have on hand.
 `sub_modifier` is empty and the underline takes the foreground colour;
 reach for `remove_modifier` and `with_underline_color` for those.").
new(Fg, Bg, Modifier) ->
    {style, Fg, Bg, Modifier, none(), default}.

-file("src/etui/style.gleam", 161).
-spec with_fg(style(), color()) -> style().
-doc(~" Set foreground color on a style.").
with_fg(S, Fg) ->
    {style, Fg, erlang:element(3, S), erlang:element(4, S), erlang:element(5, S), erlang:element(6, S)}.

-file("src/etui/style.gleam", 166).
-spec with_bg(style(), color()) -> style().
-doc(~" Set background color on a style.").
with_bg(S, Bg) ->
    {style, erlang:element(2, S), Bg, erlang:element(4, S), erlang:element(5, S), erlang:element(6, S)}.

-file("src/etui/style.gleam", 171).
-spec with_modifier(style(), modifier()) -> style().
-doc(~" Set modifier on a style.").
with_modifier(S, M) ->
    {style, erlang:element(2, S), erlang:element(3, S), M, erlang:element(5, S), erlang:element(6, S)}.

-file("src/etui/style.gleam", 177).
-spec with_underline_color(style(), color()) -> style().
-doc(~" Colour the underline separately from the text.
 Only visible with `underline()` on, and only where SGR 58 is supported.").
with_underline_color(S, C) ->
    {style, erlang:element(2, S), erlang:element(3, S), erlang:element(4, S), erlang:element(5, S), C}.

-file("src/etui/style.gleam", 182).
-spec bold_style() -> style().
-doc(~" Default colors with bold modifier.").
bold_style() ->
    new(default, default, bold()).

-file("src/etui/style.gleam", 187).
-spec reversed() -> style().
-doc(~" Default colors with reverse modifier (swap fg/bg).").
reversed() ->
    new(default, default, reverse()).

-file("src/etui/style.gleam", 192).
-spec italic_style() -> style().
-doc(~" Default colors with italic modifier.").
italic_style() ->
    new(default, default, italic()).

-file("src/etui/style.gleam", 197).
-spec dim_style() -> style().
-doc(~" Default colors with dim modifier.").
dim_style() ->
    new(default, default, dim()).

-file("src/etui/style.gleam", 202).
-spec underline_style() -> style().
-doc(~" Default colors with underline modifier.").
underline_style() ->
    new(default, default, underline()).

-file("src/etui/style.gleam", 207).
-spec add_modifier(style(), modifier()) -> style().
-doc(~" Turn modifiers on. Anything named here stops being turned off.").
add_modifier(S, M) ->
    {style, erlang:element(2, S), erlang:element(3, S), add(erlang:element(4, S), M), remove(erlang:element(5, S), M), erlang:element(6, S)}.

-file("src/etui/style.gleam", 217).
-spec remove_modifier(style(), modifier()) -> style().
-doc(~" Turn modifiers off, including ones a style underneath had turned on.
 Anything named here stops being turned on.").
remove_modifier(S, M) ->
    {style, erlang:element(2, S), erlang:element(3, S), remove(erlang:element(4, S), M), add(erlang:element(5, S), M), erlang:element(6, S)}.

-file("src/etui/style.gleam", 260).
-spec hex_digit(binary()) -> {ok, integer()} | {error, nil}.
hex_digit(C) ->
    case C of
        ~"0" ->
            {ok, 0};

        ~"1" ->
            {ok, 1};

        ~"2" ->
            {ok, 2};

        ~"3" ->
            {ok, 3};

        ~"4" ->
            {ok, 4};

        ~"5" ->
            {ok, 5};

        ~"6" ->
            {ok, 6};

        ~"7" ->
            {ok, 7};

        ~"8" ->
            {ok, 8};

        ~"9" ->
            {ok, 9};

        ~"a" ->
            {ok, 10};

        ~"A" ->
            {ok, 10};

        ~"b" ->
            {ok, 11};

        ~"B" ->
            {ok, 11};

        ~"c" ->
            {ok, 12};

        ~"C" ->
            {ok, 12};

        ~"d" ->
            {ok, 13};

        ~"D" ->
            {ok, 13};

        ~"e" ->
            {ok, 14};

        ~"E" ->
            {ok, 14};

        ~"f" ->
            {ok, 15};

        ~"F" ->
            {ok, 15};

        _ ->
            {error, nil}
    end.

-file("src/etui/style.gleam", 253).
-spec hex_pair(binary(), binary()) -> {ok, integer()} | {error, nil}.
hex_pair(Hi, Lo) ->
    case {hex_digit(Hi), hex_digit(Lo)} of
        {{ok, H}, {ok, L}} ->
            {ok, (H * 16) + L};

        {_, _} ->
            {error, nil}
    end.

-file("src/etui/style.gleam", 232).
-spec color_from_hex(binary()) -> {ok, color()} | {error, nil}.
-doc(~" Parse an RGB color from a hex string (`\"#RRGGBB\"` or `\"RRGGBB\"`).
 Returns `Error(Nil)` for malformed input.

 ```gleam
 style.color_from_hex(\"#1e1e2e\")  // Ok(Rgb(30, 30, 46))
 style.color_from_hex(\"ff5555\")   // Ok(Rgb(255, 85, 85))
 ```").
color_from_hex(Hex) ->
    S = case gleam_stdlib:string_starts_with(Hex, ~"#") of
        true ->
            gleam@string:drop_start(Hex, 1);

        false ->
            Hex
    end,
    case string:length(S) =:= 6 of
        false ->
            {error, nil};

        true ->
            Chars = gleam@string:to_graphemes(S),
            case Chars of
                [R1, R2, G1, G2, B1, B2] ->
                    case {hex_pair(R1, R2), hex_pair(G1, G2), hex_pair(B1, B2)} of
                        {{ok, R}, {ok, G}, {ok, B}} ->
                            {ok, {rgb, R, G, B}};

                        {_, _, _} ->
                            {error, nil}
                    end;

                _ ->
                    {error, nil}
            end
    end.

-file("src/etui/style.gleam", 293).
-spec patch(style(), style()) -> style().
-doc(~" Apply `over` on top of `base`.

 `Default` colours in `over` fall through to `base`. Modifiers that `over`
 turns on are added, and modifiers it turns off are taken away, so an
 overlay can clear something the base had set:

 ```gleam
 let theme = style.default_style() |> style.add_modifier(style.bold())
 let quiet = style.default_style() |> style.remove_modifier(style.bold())
 style.patch(theme, quiet)  // not bold
 ```").
patch(Base, Over) ->
    Fg = case erlang:element(2, Over) of
        default ->
            erlang:element(2, Base);

        C ->
            C
    end,
    Bg = case erlang:element(3, Over) of
        default ->
            erlang:element(3, Base);

        C@1 ->
            C@1
    end,
    Underline_color = case erlang:element(6, Over) of
        default ->
            erlang:element(6, Base);

        C@2 ->
            C@2
    end,
    {style, Fg, Bg, begin
        _pipe = erlang:element(4, Base),
        _pipe@1 = remove(_pipe, erlang:element(5, Over)),
        add(_pipe@1, erlang:element(4, Over))
    end, begin
        _pipe@2 = erlang:element(5, Base),
        _pipe@3 = remove(_pipe@2, erlang:element(4, Over)),
        add(_pipe@3, erlang:element(5, Over))
    end, Underline_color}.

-file("src/etui/style.gleam", 323).
-spec ansi_fg(color()) -> binary().
-doc(~" Foreground color escape sequence.").
ansi_fg(Color) ->
    case Color of
        default ->
            ~"";

        {indexed, 0} ->
            ~"\x{001B}[30m";

        {indexed, 1} ->
            ~"\x{001B}[31m";

        {indexed, 2} ->
            ~"\x{001B}[32m";

        {indexed, 3} ->
            ~"\x{001B}[33m";

        {indexed, 4} ->
            ~"\x{001B}[34m";

        {indexed, 5} ->
            ~"\x{001B}[35m";

        {indexed, 6} ->
            ~"\x{001B}[36m";

        {indexed, 7} ->
            ~"\x{001B}[37m";

        {indexed, 8} ->
            ~"\x{001B}[90m";

        {indexed, 9} ->
            ~"\x{001B}[91m";

        {indexed, 10} ->
            ~"\x{001B}[92m";

        {indexed, 11} ->
            ~"\x{001B}[93m";

        {indexed, 12} ->
            ~"\x{001B}[94m";

        {indexed, 13} ->
            ~"\x{001B}[95m";

        {indexed, 14} ->
            ~"\x{001B}[96m";

        {indexed, 15} ->
            ~"\x{001B}[97m";

        {indexed, N} ->
            <<<<"\x{001B}[38;5;"/utf8, (erlang:integer_to_binary(N))/binary>>/binary, "m"/utf8>>;

        {rgb, R, G, B} ->
            <<<<<<<<<<<<"\x{001B}[38;2;"/utf8, (erlang:integer_to_binary(R))/binary>>/binary, ";"/utf8>>/binary, (erlang:integer_to_binary(G))/binary>>/binary, ";"/utf8>>/binary, (erlang:integer_to_binary(B))/binary>>/binary, "m"/utf8>>
    end.

-file("src/etui/style.gleam", 355).
-spec ansi_bg(color()) -> binary().
-doc(~" Background color escape sequence.").
ansi_bg(Color) ->
    case Color of
        default ->
            ~"";

        {indexed, 0} ->
            ~"\x{001B}[40m";

        {indexed, 1} ->
            ~"\x{001B}[41m";

        {indexed, 2} ->
            ~"\x{001B}[42m";

        {indexed, 3} ->
            ~"\x{001B}[43m";

        {indexed, 4} ->
            ~"\x{001B}[44m";

        {indexed, 5} ->
            ~"\x{001B}[45m";

        {indexed, 6} ->
            ~"\x{001B}[46m";

        {indexed, 7} ->
            ~"\x{001B}[47m";

        {indexed, 8} ->
            ~"\x{001B}[100m";

        {indexed, 9} ->
            ~"\x{001B}[101m";

        {indexed, 10} ->
            ~"\x{001B}[102m";

        {indexed, 11} ->
            ~"\x{001B}[103m";

        {indexed, 12} ->
            ~"\x{001B}[104m";

        {indexed, 13} ->
            ~"\x{001B}[105m";

        {indexed, 14} ->
            ~"\x{001B}[106m";

        {indexed, 15} ->
            ~"\x{001B}[107m";

        {indexed, N} ->
            <<<<"\x{001B}[48;5;"/utf8, (erlang:integer_to_binary(N))/binary>>/binary, "m"/utf8>>;

        {rgb, R, G, B} ->
            <<<<<<<<<<<<"\x{001B}[48;2;"/utf8, (erlang:integer_to_binary(R))/binary>>/binary, ";"/utf8>>/binary, (erlang:integer_to_binary(G))/binary>>/binary, ";"/utf8>>/binary, (erlang:integer_to_binary(B))/binary>>/binary, "m"/utf8>>
    end.

-file("src/etui/style.gleam", 401).
-spec ansi_underline_color(color()) -> binary().
-doc(~" Underline colour escape sequence (SGR 58).

 Colon-separated, which is not a style choice. A terminal that does not
 implement 58 must be able to ignore the whole thing, and with semicolons
 it cannot: `ESC[58;5;9m` reads as three ordinary parameters — 58 unknown,
 then 5, then 9 — so asking for a red underline made the text blink and
 struck it through, and asking for a green one (`58;5;2`) made it blink and
 go dim. Sub-parameters after a colon belong to the parameter they follow,
 so `ESC[58:5:9m` is one attribute a terminal either knows or skips.

 The empty field in the RGB form is the colour-space id, which T.416 puts
 there and every implementation leaves empty.

 `Default` emits nothing rather than SGR 59: a cell is always written after
 a reset, so there is no stale underline colour to clear.").
ansi_underline_color(Color) ->
    case Color of
        default ->
            ~"";

        {indexed, N} ->
            <<<<"\x{001B}[58:5:"/utf8, (erlang:integer_to_binary(N))/binary>>/binary, "m"/utf8>>;

        {rgb, R, G, B} ->
            <<<<<<<<<<<<"\x{001B}[58:2::"/utf8, (erlang:integer_to_binary(R))/binary>>/binary, ":"/utf8>>/binary, (erlang:integer_to_binary(G))/binary>>/binary, ":"/utf8>>/binary, (erlang:integer_to_binary(B))/binary>>/binary, "m"/utf8>>
    end.

-file("src/etui/style.gleam", 424).
-spec resolve(style()) -> style().
-doc(~" Settle a style into what a cell actually shows: modifiers it turns off win
 over modifiers it turns on, and `sub_modifier` is spent.

 Cells hold resolved styles. Two cells that look identical must compare
 equal, or the diff repaints them every frame; an unspent `sub_modifier`
 riding along on a cell would break exactly that.").
resolve(S) ->
    case is_none(erlang:element(5, S)) of
        true ->
            S;

        false ->
            {style, erlang:element(2, S), erlang:element(3, S), remove(erlang:element(4, S), erlang:element(5, S)), none(), erlang:element(6, S)}
    end.

-file("src/etui/style.gleam", 437).
-spec ansi_modifier(modifier()) -> binary().
-doc(~" Text modifier escape sequence. Emits all active modifier bits.").
ansi_modifier(M) ->
    case is_none(M) of
        true ->
            ~"";

        false ->
            Parts = [],
            Parts@1 = case has(M, bold()) of
                true ->
                    [~"1" | Parts];

                false ->
                    Parts
            end,
            Parts@2 = case has(M, dim()) of
                true ->
                    [~"2" | Parts@1];

                false ->
                    Parts@1
            end,
            Parts@3 = case has(M, italic()) of
                true ->
                    [~"3" | Parts@2];

                false ->
                    Parts@2
            end,
            Parts@4 = case has(M, underline()) of
                true ->
                    [~"4" | Parts@3];

                false ->
                    Parts@3
            end,
            Parts@5 = case has(M, blink()) of
                true ->
                    [~"5" | Parts@4];

                false ->
                    Parts@4
            end,
            Parts@6 = case has(M, reverse()) of
                true ->
                    [~"7" | Parts@5];

                false ->
                    Parts@5
            end,
            Parts@7 = case has(M, strikethrough()) of
                true ->
                    [~"9" | Parts@6];

                false ->
                    Parts@6
            end,
            Parts@8 = case has(M, hidden()) of
                true ->
                    [~"8" | Parts@7];

                false ->
                    Parts@7
            end,
            Parts@9 = case has(M, rapid_blink()) of
                true ->
                    [~"6" | Parts@8];

                false ->
                    Parts@8
            end,
            <<<<"\x{001B}["/utf8, (gleam@string:join(Parts@9, ~";"))/binary>>/binary, "m"/utf8>>
    end.

-file("src/etui/style.gleam", 484).
-spec ansi_reset() -> binary().
-doc(~" Reset all styles.").
ansi_reset() ->
    ~"\x{001B}[0m".

