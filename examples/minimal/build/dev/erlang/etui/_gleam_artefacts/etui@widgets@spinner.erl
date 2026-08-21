-module(etui@widgets@spinner).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([spinner_new/0, with_style/2, with_label/2, with_colors/3, with_render_style/2, render/4]).
-export_type([spinner_style/0, spinner/0]).

-type spinner_style() :: dots | line | circle | bounce | mini_dot | jump | pulse | points | globe | moon | monkey | meter | hamburger | ellipsis | {custom, list(binary())}.

-type spinner() :: {spinner, spinner_style(), binary(), etui@style:color(), etui@style:color()}.

-file("src/etui/widgets/spinner.gleam", 35).
-spec spinner_new() -> spinner().
spinner_new() ->
    {spinner, dots, ~"", default, default}.

-file("src/etui/widgets/spinner.gleam", 39).
-spec with_style(spinner(), spinner_style()) -> spinner().
with_style(S, Spinner_style) ->
    {spinner, Spinner_style, erlang:element(3, S), erlang:element(4, S), erlang:element(5, S)}.

-file("src/etui/widgets/spinner.gleam", 43).
-spec with_label(spinner(), binary()) -> spinner().
with_label(S, Label) ->
    {spinner, erlang:element(2, S), Label, erlang:element(4, S), erlang:element(5, S)}.

-file("src/etui/widgets/spinner.gleam", 47).
-spec with_colors(spinner(), etui@style:color(), etui@style:color()) -> spinner().
with_colors(S, Fg, Bg) ->
    {spinner, erlang:element(2, S), erlang:element(3, S), Fg, Bg}.

-file("src/etui/widgets/spinner.gleam", 51).
-spec with_render_style(spinner(), etui@style:style()) -> spinner().
with_render_style(S, St) ->
    {spinner, erlang:element(2, S), erlang:element(3, S), erlang:element(2, St), erlang:element(3, St)}.

-file("src/etui/widgets/spinner.gleam", 157).
-spec do_nth(list(binary()), integer()) -> binary().
do_nth(Items, N) ->
    case Items of
        [] ->
            ~"?";

        [H | _] when N =< 0 ->
            H;

        [_ | Rest] ->
            do_nth(Rest, N - 1)
    end.

-file("src/etui/widgets/spinner.gleam", 153).
-spec nth_frame(list(binary()), integer()) -> binary().
nth_frame(Frames, Idx) ->
    do_nth(Frames, Idx).

-file("src/etui/widgets/spinner.gleam", 88).
-spec spin_char(spinner_style(), integer()) -> binary().
spin_char(Spinner_style, Frame) ->
    case Spinner_style of
        dots ->
            Frames = [~"⠋", ~"⠙", ~"⠹", ~"⠸", ~"⠼", ~"⠴", ~"⠦", ~"⠧", ~"⠇", ~"⠏"],
            nth_frame(Frames, etui@anim:cycle(Frame, 10));

        line ->
            Frames@1 = [~"-", ~"\\", ~"|", ~"/"],
            nth_frame(Frames@1, etui@anim:cycle(Frame, 4));

        circle ->
            Frames@2 = [~"◐", ~"◓", ~"◑", ~"◒"],
            nth_frame(Frames@2, etui@anim:cycle(Frame, 4));

        bounce ->
            Frames@3 = [~"⠁", ~"⠂", ~"⠄", ~"⠂"],
            nth_frame(Frames@3, etui@anim:cycle(Frame, 4));

        mini_dot ->
            Frames@4 = [~"⠂", ~"⠁", ~"⠈", ~"⠐", ~"⠠", ~"⢀", ~"⡀", ~"⠄"],
            nth_frame(Frames@4, etui@anim:cycle(Frame, 8));

        jump ->
            Frames@5 = [~"▀", ~"▄"],
            nth_frame(Frames@5, etui@anim:cycle(Frame, 2));

        pulse ->
            Frames@6 = [~"█", ~"▓", ~"▒", ~"░", ~"▒", ~"▓"],
            nth_frame(Frames@6, etui@anim:cycle(Frame, 6));

        points ->
            Frames@7 = [~"∙∙∙", ~"●∙∙", ~"∙●∙", ~"∙∙●"],
            nth_frame(Frames@7, etui@anim:cycle(Frame, 4));

        globe ->
            Frames@8 = [~"🌍", ~"🌎", ~"🌏"],
            nth_frame(Frames@8, etui@anim:cycle(Frame, 3));

        moon ->
            Frames@9 = [~"🌑", ~"🌒", ~"🌓", ~"🌔", ~"🌕", ~"🌖", ~"🌗", ~"🌘"],
            nth_frame(Frames@9, etui@anim:cycle(Frame, 8));

        monkey ->
            Frames@10 = [~"🙈", ~"🙉", ~"🙊"],
            nth_frame(Frames@10, etui@anim:cycle(Frame, 3));

        meter ->
            Frames@11 = [~"▱▱▱", ~"▰▱▱", ~"▰▰▱", ~"▰▰▰", ~"▰▰▱", ~"▰▱▱"],
            nth_frame(Frames@11, etui@anim:cycle(Frame, 6));

        hamburger ->
            Frames@12 = [~"☱", ~"☲", ~"☴", ~"☲"],
            nth_frame(Frames@12, etui@anim:cycle(Frame, 4));

        ellipsis ->
            Frames@13 = [~"   ", ~".  ", ~".. ", ~"..."],
            nth_frame(Frames@13, etui@anim:cycle(Frame, 4));

        {custom, Frames@14} ->
            Count = erlang:length(Frames@14),
            nth_frame(Frames@14, etui@anim:cycle(Frame, Count))
    end.

-file("src/etui/widgets/spinner.gleam", 61).
-spec render(etui@buffer:buffer(), etui@geometry:rect(), spinner(), integer()) -> etui@buffer:buffer().
render(Buf, Area, S, Frame) ->
    case (erlang:element(2, erlang:element(3, Area)) =< 0) orelse (erlang:element(3, erlang:element(3, Area)) =< 0) of
        true ->
            Buf;

        false ->
            Char = spin_char(erlang:element(2, S), Frame),
            Line = case erlang:element(3, S) of
                ~"" ->
                    Char;

                Label ->
                    <<<<Char/binary, " "/utf8>>/binary, Label/binary>>
            end,
            etui@buffer:set_string(Buf, erlang:element(2, Area), Line, etui@style:new(erlang:element(4, S), erlang:element(5, S), etui@style:none()))
    end.

