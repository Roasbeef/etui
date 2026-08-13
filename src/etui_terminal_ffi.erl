-module(etui_terminal_ffi).

-export([enter_raw/0, exit_raw/0, window_size/0, monotonic_ms/0, read_with_timeout/1,
         install_sigint_cleanup/1, uninstall_sigint_cleanup/0,
         write_cleanup/0]).

%% Run something whose failure must not stop cleanup, and say so once rather
%% than eighteen times. `catch Expr` is deprecated in OTP; this is the same
%% intent written the way the language now wants it.
try_(Fun) ->
    try Fun() of
        Value -> Value
    catch
        _:Reason -> {error, Reason}
    end.

%% Enter raw mode via user_drv.  shell:start_interactive({noshell, raw})
%% routes through user_drv's existing prim_tty instance, no second
%% prim_tty:init call, no linked-process conflicts.
enter_raw() ->
    remember_tty_path(),
    case shell:start_interactive({noshell, raw}) of
        ok                      -> ok;
        {error, already_started} -> ok;
        _                       -> ok
    end.

%% Restore cooked mode via stty(1).  Drain buffered mouse/key events first
%% so they don't leak into the shell after we exit raw mode.
%% We entered through shell:start_interactive({noshell, raw}), so restore the
%% shell reader back to cooked mode as well; stty alone is not symmetric.
exit_raw() ->
    stop_reader(),
    drain_input(50),
    try_(fun() -> shell:start_interactive({noshell, cooked}) end),
    try_(fun() -> io:setopts(user, [{echo, true}, {binary, false}]) end),
    try_(fun() -> os:cmd("stty sane") end),
    ok.

%% Write terminal restore sequences directly to /dev/tty.
%% Fallback to the current group leader if /dev/tty is unavailable.
write_cleanup() ->
    write_cleanup_to_tty(false),
    kill_watchdog(),
    ok.

%% Read and discard all data in the tty input buffer.
%% Keeps spawning readers until no data arrives within TimeoutMs.
%% Kills the reader process on timeout so it doesn't linger.
drain_input(TimeoutMs) ->
    Self = self(),
    Ref = make_ref(),
    Pid = spawn(fun() ->
        Chunk = io:get_chars("", 256),
        Self ! {Ref, Chunk}
    end),
    receive
        {Ref, _} -> drain_input(TimeoutMs)
    after TimeoutMs ->
        exit(Pid, kill),
        ok
    end.

%% Install a SIGINT handler that runs CleanupFun then halts with exit code 130.
%% Call once after entering raw mode.
%%
%% Primary path (OTP < 28 / shell mode): os:set_signal(sigint, handle) works.
%% Fallback (OTP 28 noshell): os:set_signal returns badarg.  We spawn an
%% OS-level bash watchdog that detects the Erlang VM dying and sends the
%% terminal-cleanup sequences to /dev/tty.  The watchdog also handles the
%% case where the user presses 'a' in the BEAM break handler (erlang:halt).
install_sigint_cleanup(CleanupFun) ->
    case erlang:whereis(etui_sigint_watcher) of
        undefined -> ok;
        Pid -> exit(Pid, replace)
    end,
    reset_watchdog(),
    install_watchdog(),
    SetSignalResult = try_(fun() -> os:set_signal(sigint, handle) end),
    case SetSignalResult of
        ok ->
            %% Erlang-level cleanup watcher.
            %%
            %% Two distinct failure paths need handling:
            %% 1. A real OS SIGINT routed via os:set_signal/2.
            %% 2. The app process dying asynchronously (for example because
            %%    user_drv exits it with reason 'interrupt' before normal
            %%    cleanup runs).
            Owner = self(),
            spawn(fun() ->
                try_(fun() -> erlang:register(etui_sigint_watcher, self()) end),
                receive
                    {signal, sigint} ->
                        try_(CleanupFun),
                        write_cleanup_to_tty(true),
                        kill_watchdog(),
                        erlang:halt(130);
                    {owner_down, Reason} ->
                        case Reason of
                            normal -> ok;
                            shutdown -> ok;
                            _ ->
                                try_(CleanupFun),
                                write_cleanup_to_tty(true),
                                kill_watchdog()
                        end;
                    stop ->
                        ok
                end
            end),
            spawn(fun() ->
                erlang:monitor(process, Owner),
                receive_signals(try_(fun() -> erlang:whereis(etui_sigint_watcher) end))
            end),
            ok;
        _ ->
            %% OTP 28 noshell: os:set_signal(sigint, handle) can fail.
            %% The watchdog is already installed above and covers abrupt VM exit.
            ok
    end.

receive_signals(Watcher) ->
    receive
        {signal, sigint} ->
            Watcher ! {signal, sigint};
        {'DOWN', _, process, _, Reason} ->
            Watcher ! {owner_down, Reason}
    end.

%% Spawn a bash watchdog that detects the Erlang VM dying and sends
%% terminal cleanup sequences to /dev/tty.
%%
%% The bash parent process starts an orphan background subshell and exits
%% immediately.  The Erlang port therefore points at a process that dies
%% almost instantly, port_close / erlang:halt SIGKILL is a no-op.  The
%% orphan subshell runs under launchd (macOS) or init (Linux), immune to
%% any signal the Erlang VM sends.
%%
%% A flag file distinguishes normal exit (Q) from abnormal exit (halt /
%% Ctrl+C): kill_watchdog/0 creates the file before the VM exits; the
%% subshell checks for it and skips cleanup if found.
%%
%% Uses sleep (not read -t) to stay compatible with bash 3.2 (macOS).
install_watchdog() ->
    MyPid = os:getpid(),
    Flag = "/tmp/etui_cleanup_" ++ MyPid,
    TTYPath = shell_quote(tty_path()),
    %% $'\x1b' uses ANSI C quoting supported by bash 3.2+.
    Inner =
        "trap '' INT HUP TERM" ++
        "; P=" ++ MyPid ++
        "; F=" ++ shell_quote(Flag) ++
        "; while kill -0 \"$P\" 2>/dev/null; do sleep 0.05; done" ++
        "; [ -f \"$F\" ] && { rm -f \"$F\"; exit 0; }" ++
        "; printf $'\\x1b[?1007l\\x1b[?1015l\\x1b[?1006l\\x1b[?1005l\\x1b[?1003l\\x1b[?1002l\\x1b[?1000l\\x1b[?2004l\\x1b[?1049l\\x1b[?7h\\x1b[0m\\x1b[?25h'" ++
        " 2>/dev/null > " ++ TTYPath ++
        "; stty sane < " ++ TTYPath ++ " > " ++ TTYPath ++ " 2>/dev/null",
    %% Outer bash: launch orphan subshell and exit immediately.
    Script = "(" ++ Inner ++ ") &",
    spawn(fun() ->
        case try_(fun() -> open_port(
            {spawn_executable, "/bin/bash"},
            [{args, ["-c", Script]}, binary, exit_status]
        ) end) of
            Port when is_port(Port) ->
                try_(fun() -> erlang:register(etui_watchdog_owner, self()) end),
                watchdog_loop(Port, Flag);
            _ ->
                ok
        end
    end).

watchdog_loop(Port, Flag) ->
    receive
        stop ->
            %% Normal cleanup: create flag so orphan exits without firing.
            try_(fun() -> file:write_file(Flag, <<>>) end),
            try_(fun() -> port_close(Port) end);
        {Port, _} ->
            watchdog_loop(Port, Flag)
    end.

kill_watchdog() ->
    Flag = "/tmp/etui_cleanup_" ++ os:getpid(),
    try_(fun() -> file:write_file(Flag, <<>>) end),
    case erlang:whereis(etui_watchdog_owner) of
        undefined -> ok;
        Pid -> Pid ! stop
    end.

reset_watchdog() ->
    Flag = "/tmp/etui_cleanup_" ++ os:getpid(),
    try_(fun() -> file:delete(Flag) end),
    case erlang:whereis(etui_watchdog_owner) of
        undefined -> ok;
        Pid -> Pid ! stop
    end.

%% Restore default SIGINT behaviour and stop the watcher/watchdog.
uninstall_sigint_cleanup() ->
    try_(fun() -> os:set_signal(sigint, default) end),
    case erlang:whereis(etui_sigint_watcher) of
        undefined -> ok;
        Pid -> Pid ! stop
    end,
    ok.

cleanup_sequence() ->
    "\e[?1007l\e[?1015l\e[?1006l\e[?1005l\e[?1003l\e[?1002l\e[?1000l\e[?2004l\e[?1049l\e[?7h\e[0m\e[?25h".

write_cleanup_to_tty(WithNewline) ->
    Suffix = case WithNewline of
        true -> "\r\n";
        false -> ""
    end,
    Seq = cleanup_sequence() ++ Suffix,
    Bin = unicode:characters_to_binary(Seq),
    Path = tty_path(),
    case file:write_file(Path, Bin) of
        ok ->
            ok;
        _ ->
            case file:write_file("/dev/tty", Bin) of
                ok ->
                    ok;
                _ ->
                    try_(fun() -> io:put_chars(Seq) end)
            end
    end.

remember_tty_path() ->
    case detect_tty_path() of
        {ok, Path} ->
            persistent_term:put({?MODULE, tty_path}, Path);
        error -> ok
    end.

tty_path() ->
    case persistent_term:get({?MODULE, tty_path}, undefined) of
        undefined ->
            case detect_tty_path() of
                {ok, Path} ->
                    persistent_term:put({?MODULE, tty_path}, Path),
                    Path;
                error -> "/dev/tty"
            end;
        Path -> Path
    end.

detect_tty_path() ->
    %% os:cmd/1 runs the command with stdin redirected from /dev/null, so
    %% `tty` is not reliable here. Ask ps(1) for the controlling tty of the
    %% current BEAM process instead.
    Cmd = "ps -o tty= -p " ++ os:getpid(),
    case try_(fun() -> string:trim(os:cmd(Cmd)) end) of
        TTY when is_list(TTY) ->
            normalise_tty_path(TTY);
        _ -> error
    end.

normalise_tty_path("") ->
    error;
normalise_tty_path([$?|_]) ->
    error;
normalise_tty_path("not a tty") ->
    error;
normalise_tty_path("/dev/" ++ _ = Path) ->
    {ok, Path};
normalise_tty_path(TTY) ->
    {ok, "/dev/" ++ TTY}.

shell_quote(Path) ->
    "'" ++ lists:flatten(string:replace(Path, "'", "'\"'\"'", all)) ++ "'".

%% Monotonic clock in milliseconds, for throttling window_size/0 polls.
monotonic_ms() ->
    erlang:monotonic_time(millisecond).

window_size() ->
    case io:columns() of
        {ok, Cols} ->
            case io:rows() of
                {ok, Rows} ->
                    {ok, {Cols, Rows}};
                _ ->
                    {error, could_not_get_window_size}
            end;
        _ ->
            {error, could_not_get_window_size}
    end.

%% Non-blocking read via persistent actor.
read_with_timeout(TimeoutMs) ->
    ensure_reader(self()),
    receive
        {etui_input, Bin} -> {ok, Bin}
    after TimeoutMs ->
        {error, nil}
    end.

ensure_reader(Owner) ->
    case erlang:whereis(etui_kbd_reader) of
        undefined ->
            Pid = spawn(fun() -> reader_loop(Owner) end),
            try_(fun() -> erlang:register(etui_kbd_reader, Pid) end);
        _ -> ok
    end.

reader_loop(Owner) ->
    Raw = io:get_chars("", 128),
    Owner ! {etui_input, to_binary(Raw)},
    reader_loop(Owner).

stop_reader() ->
    case erlang:whereis(etui_kbd_reader) of
        undefined -> ok;
        Pid -> exit(Pid, kill)
    end.

to_binary(Raw) ->
    case Raw of
        eof                 -> <<>>;
        B when is_binary(B) -> B;
        L when is_list(L)   ->
            case unicode:characters_to_binary(L) of
                Encoded when is_binary(Encoded) -> Encoded;
                _                               -> iolist_to_binary(L)
            end;
        _                   -> <<>>
    end.
