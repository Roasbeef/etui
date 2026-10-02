-module(image_ffi).

%% The three things this example needs from the host that the Gleam standard
%% library does not provide: its arguments, an environment lookup, and a file
%% read. They are the example's, not etui's; the library does no file I/O.
-export([arguments/0, getenv/1, read_file/1]).

arguments() ->
    [unicode:characters_to_binary(A) || A <- init:get_plain_arguments()].

getenv(Name) ->
    case os:getenv(unicode:characters_to_list(Name)) of
        false -> {error, nil};
        Value -> {ok, unicode:characters_to_binary(Value)}
    end.

read_file(Path) ->
    case file:read_file(Path) of
        {ok, Bytes} -> {ok, Bytes};
        {error, _} -> {error, nil}
    end.
