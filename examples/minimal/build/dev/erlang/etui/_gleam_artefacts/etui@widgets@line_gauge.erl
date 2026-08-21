-module(etui@widgets@line_gauge).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([line_gauge_new/1, with_label/2, with_line_set/2, with_colors/3, with_style/2, with_filled_modifier/2, render/3]).
-export_type([line_set/0, line_gauge/0, line_chars/0]).

-type line_set() :: thin_line | double_line | thick_line | braille_line | ascii_line.

-type line_gauge() :: {line_gauge, integer(), binary(), line_set(), etui@style:color(), etui@style:color(), etui@style:modifier(), etui@style:modifier()}.

-type line_chars() :: {line_chars, binary(), binary()}.

-file("src/etui/widgets/line_gauge.gleam", 60).
-spec line_gauge_new(integer()) -> line_gauge().
-doc(~" New line gauge at the given percent (clamped to 0–100).").
line_gauge_new(Percent) ->
    {line_gauge, gleam@int:clamp(Percent, 0, 100), ~"", thin_line, default, default, etui@style:none(), etui@style:dim()}.

-file("src/etui/widgets/line_gauge.gleam", 73).
-spec with_label(line_gauge(), binary()) -> line_gauge().
-doc(~" Set a label shown in the center of the gauge.").
with_label(G, Label) ->
    {line_gauge, erlang:element(2, G), Label, erlang:element(4, G), erlang:element(5, G), erlang:element(6, G), erlang:element(7, G), erlang:element(8, G)}.

-file("src/etui/widgets/line_gauge.gleam", 78).
-spec with_line_set(line_gauge(), line_set()) -> line_gauge().
-doc(~" Set the line character set.").
with_line_set(G, Ls) ->
    {line_gauge, erlang:element(2, G), erlang:element(3, G), Ls, erlang:element(5, G), erlang:element(6, G), erlang:element(7, G), erlang:element(8, G)}.

-file("src/etui/widgets/line_gauge.gleam", 83).
-spec with_colors(line_gauge(), etui@style:color(), etui@style:color()) -> line_gauge().
-doc(~" Set foreground and background colors.").
with_colors(G, Fg, Bg) ->
    {line_gauge, erlang:element(2, G), erlang:element(3, G), erlang:element(4, G), Fg, Bg, erlang:element(7, G), erlang:element(8, G)}.

-file("src/etui/widgets/line_gauge.gleam", 92).
-spec with_style(line_gauge(), etui@style:style()) -> line_gauge().
-doc(~" Set fg/bg from a Style value.").
with_style(G, S) ->
    {line_gauge, erlang:element(2, G), erlang:element(3, G), erlang:element(4, G), erlang:element(2, S), erlang:element(3, S), erlang:element(7, G), erlang:element(8, G)}.

-file("src/etui/widgets/line_gauge.gleam", 97).
-spec with_filled_modifier(line_gauge(), etui@style:modifier()) -> line_gauge().
-doc(~" Apply a modifier to the filled portion.").
with_filled_modifier(G, M) ->
    {line_gauge, erlang:element(2, G), erlang:element(3, G), erlang:element(4, G), erlang:element(5, G), erlang:element(6, G), M, erlang:element(8, G)}.

-file("src/etui/widgets/line_gauge.gleam", 108).
-spec line_chars(line_set()) -> line_chars().
line_chars(Ls) ->
    case Ls of
        thin_line ->
            {line_chars, ~"─", ~"─"};

        double_line ->
            {line_chars, ~"═", ~"═"};

        thick_line ->
            {line_chars, ~"━", ~"─"};

        braille_line ->
            {line_chars, ~"⣿", ~"⣀"};

        ascii_line ->
            {line_chars, ~"=", ~"-"}
    end.

-file("src/etui/widgets/line_gauge.gleam", 195).
-spec drop_cells(binary(), integer()) -> binary().
drop_cells(S, N) ->
    case N =< 0 of
        true ->
            S;

        false ->
            Prefix = etui@text:truncate(S, N, ~""),
            gleam@string:drop_start(S, string:length(Prefix))
    end.

-file("src/etui/widgets/line_gauge.gleam", 179).
-spec overlay_label(binary(), binary(), integer()) -> binary().
overlay_label(Base, Label, Width) ->
    Lw = etui@text:cell_width(Label),
    case Lw >= Width of
        true ->
            etui@text:truncate(Label, Width, ~"");

        false ->
            Left_pad = (Width - Lw) div 2,
            Right_pad = (Width - Lw) - Left_pad,
            Left_str = etui@text:truncate(Base, Left_pad, ~""),
            Right_str = etui@text:truncate(drop_cells(Base, Left_pad + Lw), Right_pad, ~""),
            <<<<Left_str/binary, Label/binary>>/binary, Right_str/binary>>
    end.

-file("src/etui/widgets/line_gauge.gleam", 171).
-spec repeat_char_loop(binary(), integer(), binary()) -> binary().
repeat_char_loop(Ch, N, Acc) ->
    case N =< 0 of
        true ->
            Acc;

        false ->
            repeat_char_loop(Ch, N - 1, <<Acc/binary, Ch/binary>>)
    end.

-file("src/etui/widgets/line_gauge.gleam", 167).
-spec repeat_char(binary(), integer()) -> binary().
repeat_char(Ch, N) ->
    repeat_char_loop(Ch, N, ~"").

-file("src/etui/widgets/line_gauge.gleam", 122).
-spec render(etui@buffer:buffer(), etui@geometry:rect(), line_gauge()) -> etui@buffer:buffer().
-doc(~" Render the line gauge into the first row of `area`.").
render(Buf, Area, G) ->
    case erlang:element(2, erlang:element(3, Area)) =< 0 of
        true ->
            Buf;

        false ->
            Width = erlang:element(2, erlang:element(3, Area)),
            Filled_w = (Width * erlang:element(2, G)) div 100,
            Unfilled_w = Width - Filled_w,
            Chars = line_chars(erlang:element(4, G)),
            Filled_str = repeat_char(erlang:element(2, Chars), Filled_w),
            Unfilled_str = repeat_char(erlang:element(3, Chars), Unfilled_w),
            Raw_line = <<Filled_str/binary, Unfilled_str/binary>>,
            Line = case erlang:element(3, G) of
                ~"" ->
                    Raw_line;

                _ ->
                    overlay_label(Raw_line, erlang:element(3, G), Width)
            end,
            Pos = erlang:element(2, Area),
            Y = erlang:element(3, Pos),
            Buf@1 = etui@buffer:set_string(Buf, {position, erlang:element(2, Pos), Y}, etui@text:truncate(Line, Filled_w, ~""), etui@style:new(erlang:element(5, G), erlang:element(6, G), erlang:element(7, G))),
            etui@buffer:set_string(Buf@1, {position, erlang:element(2, Pos) + Filled_w, Y}, etui@text:truncate(drop_cells(Line, Filled_w), Unfilled_w, ~""), etui@style:new(erlang:element(5, G), erlang:element(6, G), erlang:element(8, G)))
    end.

