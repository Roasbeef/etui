-module(etui@backend).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([default_options/0, init/1, render/3, poll/3, next_size/2, cleanup/2, clear_and_home/0, op_to_ansi/1, ops_to_ansi/1, restore_ops/0, restore_sequence/0]).
-export_type([render_op/0, mouse_button/0, input_event/0, terminal_size/0, backend/1, options/0, error/0]).

-type render_op() :: {move_cursor, integer(), integer()} | {write, binary()} | clear_screen | enter_alt_screen | exit_alt_screen | enable_mouse | disable_mouse | enable_bracketed_paste | disable_bracketed_paste.

-type mouse_button() :: mouse_left | mouse_middle | mouse_right.

-type input_event() :: {key_press, binary()} | {resize, integer(), integer()} | tick | {mouse_press, integer(), integer(), mouse_button()} | {mouse_release, integer(), integer(), mouse_button()} | {mouse_scroll, integer(), integer(), boolean()} | {mouse_drag, integer(), integer(), mouse_button()} | {mouse_move, integer(), integer()} | {paste, binary()}.

-type terminal_size() :: {terminal_size, integer(), integer()}.

-type backend(DPX) :: {backend, fun(() -> {ok, DPX} | {error, error()}), fun((DPX, list(render_op())) -> {ok, DPX} | {error, error()}), fun((DPX, integer()) -> {ok, {input_event(), DPX}} | {error, error()}), fun((DPX) -> {ok, {terminal_size(), DPX}} | {error, error()}), fun((DPX) -> nil)}.

-type options() :: {options, boolean(), boolean()}.

-type error() :: {terminal_unsupported, binary()} | {i_o_error, binary()} | interrupted.

-file("src/etui/backend.gleam", 92).
-spec default_options() -> options().
-doc(~" Mouse off, bracketed paste off.").
default_options() ->
    {options, false, false}.

-file("src/etui/backend.gleam", 105).
-spec init(backend(DPY)) -> {ok, DPY} | {error, error()}.
init(Backend) ->
    (erlang:element(2, Backend))().

-file("src/etui/backend.gleam", 109).
-spec render(backend(DQC), DQC, list(render_op())) -> {ok, DQC} | {error, error()}.
render(Backend, State, Ops) ->
    (erlang:element(3, Backend))(State, Ops).

-file("src/etui/backend.gleam", 117).
-spec poll(backend(DQH), DQH, integer()) -> {ok, {input_event(), DQH}} | {error, error()}.
poll(Backend, State, Timeout_ms) ->
    (erlang:element(4, Backend))(State, Timeout_ms).

-file("src/etui/backend.gleam", 125).
-spec next_size(backend(DQL), DQL) -> {ok, {terminal_size(), DQL}} | {error, error()}.
next_size(Backend, State) ->
    (erlang:element(5, Backend))(State).

-file("src/etui/backend.gleam", 132).
-spec cleanup(backend(DQP), DQP) -> nil.
cleanup(Backend, State) ->
    (erlang:element(6, Backend))(State).

-file("src/etui/backend.gleam", 139).
-spec clear_and_home() -> list(render_op()).
clear_and_home() ->
    [clear_screen, {move_cursor, 0, 0}].

-file("src/etui/backend.gleam", 149).
-spec op_to_ansi(render_op()) -> binary().
-doc(~" The escape sequence for one render op.

 One table, not one per backend. The three backends each carried a copy,
 and the copies had already drifted: `EnableMouse` asked for click
 tracking (1000) on the JavaScript targets and not on Erlang, so the same
 program reported subtly different mouse events depending on where it ran.").
op_to_ansi(Op) ->
    case Op of
        {write, S} ->
            S;

        {move_cursor, X, Y} ->
            <<<<<<<<"\x{001B}["/utf8, (erlang:integer_to_binary(Y + 1))/binary>>/binary, ";"/utf8>>/binary, (erlang:integer_to_binary(X + 1))/binary>>/binary, "H"/utf8>>;

        clear_screen ->
            ~"\x{001B}[2J\x{001B}[H";

        enter_alt_screen ->
            ~"\x{001B}[?1049h";

        exit_alt_screen ->
            ~"\x{001B}[?1049l";

        enable_mouse ->
            ~"\x{001B}[?1002h\x{001B}[?1006h";

        disable_mouse ->
            ~"\x{001B}[?1007l\x{001B}[?1015l\x{001B}[?1006l\x{001B}[?1005l\x{001B}[?1003l\x{001B}[?1002l\x{001B}[?1000l";

        enable_bracketed_paste ->
            ~"\x{001B}[?2004h";

        disable_bracketed_paste ->
            ~"\x{001B}[?2004l"
    end.

-file("src/etui/backend.gleam", 171).
-spec ops_to_ansi(list(render_op())) -> binary().
-doc(~" Concatenated escape sequences for a list of ops.").
ops_to_ansi(Ops) ->
    gleam@list:fold(Ops, ~"", fun(Acc, Op) ->
        <<Acc/binary, (op_to_ansi(Op))/binary>>
    end).

-file("src/etui/backend.gleam", 181).
-spec restore_ops() -> list(render_op()).
-doc(~" Everything an app has to undo before the terminal is someone else's again.

 Unconditional, and in this order on purpose: a cleanup path runs when
 things have already gone wrong, and asking a terminal to leave a mode it
 was never in costs nothing, while tracking which modes were entered costs
 a correct answer exactly when the state is least trustworthy.").
restore_ops() ->
    [disable_mouse, disable_bracketed_paste, exit_alt_screen, {write, ~"\x{001B}[?7h\x{001B}[0m\x{001B}[?25h"}].

-file("src/etui/backend.gleam", 199).
-spec restore_sequence() -> binary().
-doc(~" `restore_ops` as the bytes to send.

 The single source for the restore sequence on every target, including the
 two places that cannot call Gleam: the shell watchdog that fires when the
 runtime dies without unwinding, and the Node exit handler. Both are handed
 this string rather than keeping a copy of it.").
restore_sequence() ->
    ops_to_ansi(restore_ops()).

