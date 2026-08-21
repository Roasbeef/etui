-module(etui@backend@erlang).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([new_with_options/1, new/0, new_with_mouse/0]).
-export_type([erlang_terminal_state/0]).

-type erlang_terminal_state() :: {erlang_terminal_state, boolean(), integer(), integer(), boolean(), integer(), integer(), binary(), list(etui@backend:input_event())}.

-file("src/etui/backend/erlang.gleam", 298).
-spec terminal_cleanup() -> nil.
terminal_cleanup() ->
    etui_terminal_ffi:uninstall_sigint_cleanup(),
    etui_terminal_ffi:write_cleanup(etui@backend:restore_sequence()),
    etui_terminal_ffi:exit_raw(),
    etui_tty_state:set_raw(false),
    nil.

-file("src/etui/backend/erlang.gleam", 306).
-spec cleanup_terminal(erlang_terminal_state()) -> nil.
cleanup_terminal(_) ->
    terminal_cleanup().

-file("src/etui/backend/erlang.gleam", 286).
-spec get_terminal_size(erlang_terminal_state()) -> {ok, {etui@backend:terminal_size(), erlang_terminal_state()}} | {error, etui@backend:error()}.
get_terminal_size(State) ->
    case etui_terminal_ffi:window_size() of
        {ok, {W, H}} ->
            {ok, {{terminal_size, W, H}, State}};

        {error, _} ->
            {ok, {{terminal_size, 80, 24}, State}}
    end.

-file("src/etui/backend/erlang.gleam", 279).
-spec poll_interval(erlang_terminal_state(), integer()) -> integer().
poll_interval(State, Now) ->
    case (Now - erlang:element(7, State)) < 400 of
        true ->
            16;

        false ->
            100
    end.

-file("src/etui/backend/erlang.gleam", 248).
-spec check_resize(erlang_terminal_state()) -> {erlang_terminal_state(), list(etui@backend:input_event())}.
check_resize(State) ->
    Now = etui_terminal_ffi:monotonic_ms(),
    case (Now - erlang:element(6, State)) < poll_interval(State, Now) of
        true ->
            {State, []};

        false ->
            Checked = {erlang_terminal_state, erlang:element(2, State), erlang:element(3, State), erlang:element(4, State), erlang:element(5, State), Now, erlang:element(7, State), erlang:element(8, State), erlang:element(9, State)},
            case etui_terminal_ffi:window_size() of
                {ok, {C, R}} ->
                    case (C =:= erlang:element(3, State)) andalso (R =:= erlang:element(4, State)) of
                        true ->
                            {Checked, []};

                        false ->
                            {{erlang_terminal_state, erlang:element(2, Checked), C, R, erlang:element(5, Checked), erlang:element(6, Checked), Now, erlang:element(8, Checked), erlang:element(9, Checked)}, [{resize, C, R}]}
                    end;

                {error, _} ->
                    {Checked, []}
            end
    end.

-file("src/etui/backend/erlang.gleam", 233).
-spec read_events(erlang_terminal_state(), integer()) -> {list(etui@backend:input_event()), binary()}.
read_events(State, Timeout_ms) ->
    case etui_terminal_ffi:read_with_timeout(Timeout_ms) of
        {ok, Chunk} ->
            {parsed, Events, Pending} = etui@input:parse(<<(erlang:element(8, State))/binary, Chunk/binary>>),
            {Events, Pending};

        {error, _} ->
            {etui@input:flush(erlang:element(8, State)), ~""}
    end.

-file("src/etui/backend/erlang.gleam", 211).
-spec poll_input(erlang_terminal_state(), integer()) -> {ok, {etui@backend:input_event(), erlang_terminal_state()}} | {error, etui@backend:error()}.
-doc(~" Return the next input event.

 One read can carry several key presses (typing faster than the frame rate,
 or a paste), and it can also stop in the middle of an escape sequence. The
 backend therefore decodes a read into a queue of events and hands them out
 one per call, keeping any trailing partial sequence in `pending` for the
 next read. Previously a whole read became a single `KeyPress`, so only the
 first key of a burst survived.").
poll_input(State, Timeout_ms) ->
    case erlang:element(9, State) of
        [Event | Rest] ->
            {ok, {Event, {erlang_terminal_state, erlang:element(2, State), erlang:element(3, State), erlang:element(4, State), erlang:element(5, State), erlang:element(6, State), erlang:element(7, State), erlang:element(8, State), Rest}}};

        [] ->
            {Input_events, Pending} = read_events(State, Timeout_ms),
            {Sized, Resize_events} = check_resize(State),
            Next = {erlang_terminal_state, erlang:element(2, Sized), erlang:element(3, Sized), erlang:element(4, Sized), erlang:element(5, Sized), erlang:element(6, Sized), erlang:element(7, Sized), Pending, []},
            case lists:append(Resize_events, Input_events) of
                [] ->
                    {ok, {tick, Next}};

                [Event@1 | Rest@1] ->
                    {ok, {Event@1, {erlang_terminal_state, erlang:element(2, Next), erlang:element(3, Next), erlang:element(4, Next), erlang:element(5, Next), erlang:element(6, Next), erlang:element(7, Next), erlang:element(8, Next), Rest@1}}}
            end
    end.

-file("src/etui/backend/erlang.gleam", 313).
-spec write_ops_to_stdout(list(etui@backend:render_op())) -> {ok, nil} | {error, binary()}.
write_ops_to_stdout(Ops) ->
    Output = begin
        _pipe = Ops,
        gleam@list:fold(_pipe, ~"", fun(Acc, Op) ->
            <<Acc/binary, (etui@backend:op_to_ansi(Op))/binary>>
        end)
    end,
    case Output of
        ~"" ->
            {ok, nil};

        S ->
            io:put_chars(S),
            {ok, nil}
    end.

-file("src/etui/backend/erlang.gleam", 193).
-spec render_ops(erlang_terminal_state(), list(etui@backend:render_op())) -> {ok, erlang_terminal_state()} | {error, etui@backend:error()}.
render_ops(State, Ops) ->
    case write_ops_to_stdout(Ops) of
        {ok, nil} ->
            {ok, State};

        {error, Reason} ->
            {error, {i_o_error, Reason}}
    end.

-file("src/etui/backend/erlang.gleam", 186).
-spec append_if(list(etui@backend:render_op()), boolean(), etui@backend:render_op()) -> list(etui@backend:render_op()).
append_if(Ops, Cond, Op) ->
    case Cond of
        true ->
            lists:append(Ops, [Op]);

        false ->
            Ops
    end.

-file("src/etui/backend/erlang.gleam", 151).
-spec init_terminal(etui@backend:options()) -> {ok, erlang_terminal_state()} | {error, etui@backend:error()}.
init_terminal(Opts) ->
    etui_tty_state:init(),
    Init_ops = begin
        _pipe = [enter_alt_screen, {write, ~"\x{001B}[?7l"}, clear_screen],
        _pipe@1 = append_if(_pipe, erlang:element(2, Opts), enable_mouse),
        append_if(_pipe@1, erlang:element(3, Opts), enable_bracketed_paste)
    end,
    case write_ops_to_stdout(Init_ops) of
        {ok, nil} ->
            etui_terminal_ffi:enter_raw(),
            etui_tty_state:set_raw(true),
            {Cols, Rows} = case etui_terminal_ffi:window_size() of
                {ok, {C, R}} ->
                    {C, R};

                {error, _} ->
                    {80, 24}
            end,
            etui_terminal_ffi:install_sigint_cleanup(fun() ->
                terminal_cleanup()
            end, etui@backend:restore_sequence()),
            {ok, {erlang_terminal_state, true, Cols, Rows, erlang:element(2, Opts), etui_terminal_ffi:monotonic_ms(), etui_terminal_ffi:monotonic_ms(), ~"", []}};

        {error, Reason} ->
            {error, {i_o_error, Reason}}
    end.

-file("src/etui/backend/erlang.gleam", 67).
-spec new_with_options(etui@backend:options()) -> etui@backend:backend(erlang_terminal_state()).
-doc(~" Backend with an explicit feature set.

 ```gleam
 erlang.new_with_options(erlang.Options(mouse: True, paste: True))
 ```").
new_with_options(Opts) ->
    {backend, fun() ->
        init_terminal(Opts)
    end, fun render_ops/2, fun poll_input/2, fun get_terminal_size/1, fun cleanup_terminal/1}.

-file("src/etui/backend/erlang.gleam", 54).
-spec new() -> etui@backend:backend(erlang_terminal_state()).
new() ->
    new_with_options(etui@backend:default_options()).

-file("src/etui/backend/erlang.gleam", 58).
-spec new_with_mouse() -> etui@backend:backend(erlang_terminal_state()).
new_with_mouse() ->
    new_with_options(begin
        _record = etui@backend:default_options(),
        {options, true, erlang:element(3, _record)}
    end).

