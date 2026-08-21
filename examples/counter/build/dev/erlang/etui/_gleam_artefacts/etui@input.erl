-module(etui@input).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([parse/1, flush/1]).
-export_type([parsed/0]).

-type parsed() :: {parsed, list(etui@backend:input_event()), binary()}.

-file("src/etui/input.gleam", 116).
-spec ss3_key(binary()) -> binary().
ss3_key(C) ->
    case C of
        ~"A" ->
            ~"up";

        ~"B" ->
            ~"down";

        ~"C" ->
            ~"right";

        ~"D" ->
            ~"left";

        ~"H" ->
            ~"home";

        ~"F" ->
            ~"end";

        ~"P" ->
            ~"f1";

        ~"Q" ->
            ~"f2";

        ~"R" ->
            ~"f3";

        ~"S" ->
            ~"f4";

        Other ->
            Other
    end.

-file("src/etui/input.gleam", 109).
-spec parse_ss3(list(binary())) -> {ok, {etui@backend:input_event(), list(binary())}} | {error, nil}.
parse_ss3(After) ->
    case After of
        [] ->
            {error, nil};

        [C | Rest] ->
            {ok, {{key_press, ss3_key(C)}, Rest}}
    end.

-file("src/etui/input.gleam", 229).
-spec modifier_prefix(binary()) -> binary().
modifier_prefix(P2) ->
    case gleam_stdlib:parse_int(P2) of
        {error, nil} ->
            ~"";

        {ok, N} ->
            Bits = N - 1,
            Ctrl = case erlang:'band'(Bits, 4) /= 0 of
                true ->
                    ~"ctrl+";

                false ->
                    ~""
            end,
            Alt = case erlang:'band'(Bits, 2) /= 0 of
                true ->
                    ~"alt+";

                false ->
                    ~""
            end,
            Shift = case erlang:'band'(Bits, 1) /= 0 of
                true ->
                    ~"shift+";

                false ->
                    ~""
            end,
            <<<<Ctrl/binary, Alt/binary>>/binary, Shift/binary>>
    end.

-file("src/etui/input.gleam", 203).
-spec tilde_key(binary()) -> binary().
tilde_key(P1) ->
    case P1 of
        ~"1" ->
            ~"home";

        ~"2" ->
            ~"insert";

        ~"3" ->
            ~"delete";

        ~"4" ->
            ~"end";

        ~"5" ->
            ~"pageup";

        ~"6" ->
            ~"pagedown";

        ~"11" ->
            ~"f1";

        ~"12" ->
            ~"f2";

        ~"13" ->
            ~"f3";

        ~"14" ->
            ~"f4";

        ~"15" ->
            ~"f5";

        ~"17" ->
            ~"f6";

        ~"18" ->
            ~"f7";

        ~"19" ->
            ~"f8";

        ~"20" ->
            ~"f9";

        ~"21" ->
            ~"f10";

        ~"23" ->
            ~"f11";

        ~"24" ->
            ~"f12";

        Other ->
            Other
    end.

-file("src/etui/input.gleam", 191).
-spec split_params(binary()) -> {binary(), binary()}.
split_params(Params) ->
    case Params of
        ~"" ->
            {~"", ~""};

        _ ->
            case gleam@string:split(Params, ~";") of
                [] ->
                    {~"", ~""};

                [A] ->
                    {A, ~""};

                [A@1, B | _] ->
                    {A@1, B}
            end
    end.

-file("src/etui/input.gleam", 171).
-spec csi_key(binary(), binary()) -> binary().
csi_key(Params, Final) ->
    {P1, P2} = split_params(Params),
    Base = case Final of
        ~"A" ->
            ~"up";

        ~"B" ->
            ~"down";

        ~"C" ->
            ~"right";

        ~"D" ->
            ~"left";

        ~"H" ->
            ~"home";

        ~"F" ->
            ~"end";

        ~"Z" ->
            ~"backtab";

        ~"P" ->
            ~"f1";

        ~"Q" ->
            ~"f2";

        ~"R" ->
            ~"f3";

        ~"S" ->
            ~"f4";

        ~"~" ->
            tilde_key(P1);

        Other ->
            Other
    end,
    <<(modifier_prefix(P2))/binary, Base/binary>>.

-file("src/etui/input.gleam", 254).
-spec parse_paste(list(binary()), list(binary())) -> {ok, {etui@backend:input_event(), list(binary())}} | {error, nil}.
parse_paste(Gs, Rev) ->
    case Gs of
        [] ->
            {error, nil};

        [~"\x{001B}", ~"[", ~"2", ~"0", ~"1", ~"~" | Rest] ->
            {ok, {{paste, erlang:list_to_binary(lists:reverse(Rev))}, Rest}};

        [G | Rest@1] ->
            parse_paste(Rest@1, [G | Rev])
    end.

-file("src/etui/input.gleam", 161).
-spec is_final_byte(binary()) -> boolean().
is_final_byte(G) ->
    case gleam@string:to_utf_codepoints(G) of
        [Cp | _] ->
            N = gleam_stdlib:identity(Cp),
            (N >= 64) andalso (N =< 126);

        [] ->
            false
    end.

-file("src/etui/input.gleam", 147).
-spec collect_csi(list(binary()), list(binary())) -> {ok, {binary(), binary(), list(binary())}} | {error, nil}.
collect_csi(Gs, Rev_params) ->
    case Gs of
        [] ->
            {error, nil};

        [G | Rest] ->
            case is_final_byte(G) of
                true ->
                    {ok, {erlang:list_to_binary(lists:reverse(Rev_params)), G, Rest}};

                false ->
                    collect_csi(Rest, [G | Rev_params])
            end
    end.

-file("src/etui/input.gleam", 306).
-spec button_of(integer()) -> etui@backend:mouse_button().
button_of(Bits) ->
    case Bits of
        1 ->
            mouse_middle;

        2 ->
            mouse_right;

        _ ->
            mouse_left
    end.

-file("src/etui/input.gleam", 289).
-spec mouse_event(integer(), integer(), integer(), boolean()) -> etui@backend:input_event().
mouse_event(Cb, X, Y, Pressed) ->
    Button_bits = erlang:'band'(Cb, 3),
    Motion = erlang:'band'(Cb, 32) /= 0,
    Wheel = erlang:'band'(Cb, 64) /= 0,
    case {Wheel, Motion, Button_bits} of
        {true, _, B} ->
            {mouse_scroll, X, Y, B =:= 0};

        {false, true, 3} ->
            {mouse_move, X, Y};

        {false, true, B@1} ->
            {mouse_drag, X, Y, button_of(B@1)};

        {false, false, B@2} ->
            case Pressed of
                true ->
                    {mouse_press, X, Y, button_of(B@2)};

                false ->
                    {mouse_release, X, Y, button_of(B@2)}
            end
    end.

-file("src/etui/input.gleam", 270).
-spec parse_sgr_mouse(list(binary())) -> {ok, {etui@backend:input_event(), list(binary())}} | {error, nil}.
parse_sgr_mouse(Body) ->
    gleam@result:'try'(collect_csi(Body, []), fun(_use0) ->
        {Params, Final, Rest} = _use0,
        case gleam@string:split(Params, ~";") of
            [Cb_s, Cx_s, Cy_s] ->
                case {gleam_stdlib:parse_int(Cb_s), gleam_stdlib:parse_int(Cx_s), gleam_stdlib:parse_int(Cy_s)} of
                    {{ok, Cb}, {ok, Cx}, {ok, Cy}} ->
                        {ok, {mouse_event(Cb, Cx - 1, Cy - 1, Final =:= ~"M"), Rest}};

                    {_, _, _} ->
                        {ok, {{key_press, <<<<<<"\x{001B}"/utf8, "[<"/utf8>>/binary, Params/binary>>/binary, Final/binary>>}, Rest}}
                end;

            _ ->
                {ok, {{key_press, <<<<<<"\x{001B}"/utf8, "[<"/utf8>>/binary, Params/binary>>/binary, Final/binary>>}, Rest}}
        end
    end).

-file("src/etui/input.gleam", 132).
-spec parse_csi(list(binary())) -> {ok, {etui@backend:input_event(), list(binary())}} | {error, nil}.
parse_csi(After) ->
    case After of
        [~"<" | Body] ->
            parse_sgr_mouse(Body);

        _ ->
            gleam@result:'try'(collect_csi(After, []), fun(_use0) ->
                {Params, Final, Rest} = _use0,
                case {Params, Final} of
                    {~"200", ~"~"} ->
                        parse_paste(Rest, []);

                    {_, _} ->
                        {ok, {{key_press, csi_key(Params, Final)}, Rest}}
                end
            end)
    end.

-file("src/etui/input.gleam", 98).
-spec parse_esc(list(binary())) -> {ok, {etui@backend:input_event(), list(binary())}} | {error, nil}.
parse_esc(Rest) ->
    case Rest of
        [] ->
            {error, nil};

        [~"[" | After] ->
            parse_csi(After);

        [~"O" | After@1] ->
            parse_ss3(After@1);

        [C | After@2] ->
            {ok, {{key_press, <<"alt+"/utf8, C/binary>>}, After@2}}
    end.

-file("src/etui/input.gleam", 341).
-spec letter_of(integer()) -> binary().
letter_of(N) ->
    string:lowercase(gleam@int:to_base36(N + 9)).

-file("src/etui/input.gleam", 327).
-spec control_key(binary()) -> binary().
control_key(G) ->
    case gleam@string:to_utf_codepoints(G) of
        [Cp] ->
            N = gleam_stdlib:identity(Cp),
            case (N >= 1) andalso (N =< 26) of
                true ->
                    <<"ctrl+"/utf8, (letter_of(N))/binary>>;

                false ->
                    G
            end;

        _ ->
            G
    end.

-file("src/etui/input.gleam", 317).
-spec simple_key(binary()) -> binary().
simple_key(G) ->
    case G of
        ~"\r" ->
            ~"enter";

        ~"\n" ->
            ~"enter";

        ~"\t" ->
            ~"tab";

        ~"\x{007F}" ->
            ~"backspace";

        ~"\x{0008}" ->
            ~"backspace";

        _ ->
            control_key(G)
    end.

-file("src/etui/input.gleam", 75).
-spec parse_loop(list(binary()), list(etui@backend:input_event())) -> {list(etui@backend:input_event()), list(binary())}.
parse_loop(Gs, Rev) ->
    case Gs of
        [] ->
            {Rev, []};

        [G | Rest] ->
            case G =:= ~"\x{001B}" of
                false ->
                    parse_loop(Rest, [{key_press, simple_key(G)} | Rev]);

                true ->
                    case parse_esc(Rest) of
                        {ok, {Event, Remaining}} ->
                            parse_loop(Remaining, [Event | Rev]);

                        {error, nil} ->
                            {Rev, Gs}
                    end
            end
    end.

-file("src/etui/input.gleam", 53).
-spec parse(binary()) -> parsed().
-doc(~" Decode as many events as possible from `chunk`.

 ```gleam
 input.parse(\"ab\")                  // two KeyPress events
 input.parse(\"\\u{001B}[A\")          // KeyPress(\"up\")
 input.parse(\"\\u{001B}[\")           // no events, remainder \"\\u{001B}[\"
 ```").
parse(Chunk) ->
    {Rev_events, Remainder} = parse_loop(gleam@string:to_graphemes(Chunk), []),
    {parsed, lists:reverse(Rev_events), erlang:list_to_binary(Remainder)}.

-file("src/etui/input.gleam", 65).
-spec flush(binary()) -> list(etui@backend:input_event()).
-doc(~" Turn a leftover remainder into events once it is clear no more input is
 coming (the read timed out).

 A remainder always starts with ESC. If that is all it is, the user pressed
 Escape. A genuinely truncated sequence also yields Escape; its trailing
 bytes are dropped rather than delivered as stray key presses, because a
 half escape sequence is not text the user typed.").
flush(Remainder) ->
    case Remainder of
        ~"" ->
            [];

        _ ->
            [{key_press, ~"esc"}]
    end.

