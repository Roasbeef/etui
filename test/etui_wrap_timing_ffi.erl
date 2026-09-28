-module(etui_wrap_timing_ffi).
-export([monotonic_ms/0]).

%% The long-word wrap test times itself, and gleam_stdlib has no clock.
monotonic_ms() ->
    erlang:monotonic_time(millisecond).
