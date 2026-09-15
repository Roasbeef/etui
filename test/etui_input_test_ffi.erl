-module(etui_input_test_ffi).
-export([with_closed_input/2]).

%% The fake console permits one read only. Even a regression that re-reads
%% EOF cannot flood a mailbox: its second io_request receives no reply.
with_closed_input(Kind, Action) ->
    Previous = group_leader(),
    Console = spawn(fun() -> console(Kind, ready) end),
    true = group_leader(Console, self()),
    try
        Result = Action(),
        %% A closure event must also retire its producer. Otherwise the
        %% backend could report failure while its reader still floods it.
        case whereis(etui_kbd_reader) of
            undefined -> ok;
            LiveReader ->
                Ref = monitor(process, LiveReader),
                receive {'DOWN', Ref, process, LiveReader, _} -> ok
                after 1000 -> error(reader_did_not_stop)
                end
        end,
        Result
    after
        true = group_leader(Previous, self()),
        case whereis(etui_kbd_reader) of
            undefined -> ok;
            Reader ->
                Monitor = monitor(process, Reader),
                exit(Reader, kill),
                receive {'DOWN', Monitor, process, Reader, _} -> ok end
        end,
        exit(Console, kill)
    end.

console(Kind, State) ->
    receive
        {io_request, From, Ref, {get_chars, _, _, _}} when State =:= ready ->
            Reply = case Kind of eof -> eof; failed -> {error, terminated} end,
            From ! {io_reply, Ref, Reply},
            console(Kind, spent);
        {io_request, _From, _Ref, {get_chars, _, _, _}} ->
            console(Kind, spent);
        {io_request, From, Ref, _Other} ->
            From ! {io_reply, Ref, {error, enotsup}},
            console(Kind, State)
    end.
