-module(etui@anim).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([anim_new/0, tick/1, reset/1, is_done/2, lerp/4, ease_out/4, ease_in/4, oscillate/4, blink/2, cycle/2, ease_in_out/4, interpolate/5, sequence/3]).
-export_type([anim_state/0, easing/0, keyframe/0]).

-type anim_state() :: {anim_state, integer()}.

-type easing() :: linear | ease_in | ease_out | ease_in_out.

-type keyframe() :: {keyframe, integer(), integer()}.

-file("src/etui/anim.gleam", 11).
-spec anim_new() -> anim_state().
anim_new() ->
    {anim_state, 0}.

-file("src/etui/anim.gleam", 15).
-spec tick(anim_state()) -> anim_state().
tick(State) ->
    {anim_state, erlang:element(2, State) + 1}.

-file("src/etui/anim.gleam", 19).
-spec reset(anim_state()) -> anim_state().
reset(_) ->
    {anim_state, 0}.

-file("src/etui/anim.gleam", 23).
-spec is_done(anim_state(), integer()) -> boolean().
is_done(State, Duration) ->
    erlang:element(2, State) >= Duration.

-file("src/etui/anim.gleam", 31).
-spec lerp(integer(), integer(), integer(), integer()) -> integer().
-doc(~" Linear interpolation from `start` to `end_` over `duration` frames.").
lerp(Start, End_, Frame, Duration) ->
    case Duration =< 0 of
        true ->
            End_;

        false ->
            T = gleam@int:clamp(Frame, 0, Duration),
            Start + case Duration of
                0 ->
                    0;

                _value ->
                    ((End_ - Start) * T) div _value
            end
    end.

-file("src/etui/anim.gleam", 42).
-spec ease_out(integer(), integer(), integer(), integer()) -> integer().
-doc(~" EaseOut (fast start, slow end). Quadratic approximation with integers.").
ease_out(Start, End_, Frame, Duration) ->
    case Duration =< 0 of
        true ->
            End_;

        false ->
            T = case Duration of
                0 ->
                    0;

                _value ->
                    (gleam@int:clamp(Frame, 0, Duration) * 100) div _value
            end,
            Curve = (T * (200 - T)) div 100,
            Start + (((End_ - Start) * Curve) div 100)
    end.

-file("src/etui/anim.gleam", 54).
-spec ease_in(integer(), integer(), integer(), integer()) -> integer().
-doc(~" EaseIn (slow start, fast end). Quadratic approximation.").
ease_in(Start, End_, Frame, Duration) ->
    case Duration =< 0 of
        true ->
            End_;

        false ->
            T = case Duration of
                0 ->
                    0;

                _value ->
                    (gleam@int:clamp(Frame, 0, Duration) * 100) div _value
            end,
            Curve = (T * T) div 100,
            Start + (((End_ - Start) * Curve) div 100)
    end.

-file("src/etui/anim.gleam", 67).
-spec oscillate(integer(), integer(), integer(), integer()) -> integer().
-doc(~" Oscillate between `min` and `max` with a given `period` (in frames).
 Returns current value in the triangle wave.").
oscillate(Min, Max, Frame, Period) ->
    case Period =< 0 of
        true ->
            Min;

        false ->
            Range = Max - Min,
            Half = Period div 2,
            Pos = case Period of
                0 ->
                    0;

                _value ->
                    Frame rem _value
            end,
            case Pos < Half of
                true ->
                    Min + case gleam@int:max(1, Half) of
                        0 ->
                            0;

                        _value@1 ->
                            (Range * Pos) div _value@1
                    end;

                false ->
                    Max - case gleam@int:max(1, Period - Half) of
                        0 ->
                            0;

                        _value@2 ->
                            (Range * (Pos - Half)) div _value@2
                    end
            end
    end.

-file("src/etui/anim.gleam", 84).
-spec blink(integer(), integer()) -> boolean().
-doc(~" Returns True during the \"on\" half of each blink period.
 `period` ≤ 0 means always on.").
blink(Frame, Period) ->
    case Period =< 0 of
        true ->
            true;

        false ->
            case Period of
                0 ->
                    0;

                _value ->
                    Frame rem _value
            end < (Period div 2)
    end.

-file("src/etui/anim.gleam", 92).
-spec cycle(integer(), integer()) -> integer().
-doc(~" Cycle through [0, count) returning the current index for the given frame.").
cycle(Frame, Count) ->
    case Count =< 0 of
        true ->
            0;

        false ->
            case Count of
                0 ->
                    0;

                _value ->
                    Frame rem _value
            end
    end.

-file("src/etui/anim.gleam", 126).
-spec ease_in_out(integer(), integer(), integer(), integer()) -> integer().
-doc(~" EaseInOut (slow start, fast middle, slow end). Quadratic approximation.").
ease_in_out(Start, End_, Frame, Duration) ->
    case Duration =< 0 of
        true ->
            End_;

        false ->
            T = case Duration of
                0 ->
                    0;

                _value ->
                    (gleam@int:clamp(Frame, 0, Duration) * 100) div _value
            end,
            Curve = case T < 50 of
                true ->
                    (T * T) div 50;

                false ->
                    Inv = 100 - T,
                    100 - ((Inv * Inv) div 50)
            end,
            Start + (((End_ - Start) * Curve) div 100)
    end.

-file("src/etui/anim.gleam", 110).
-spec interpolate(integer(), integer(), integer(), integer(), easing()) -> integer().
-doc(~" Unified interpolation with selectable easing curve.").
interpolate(Start, End_, Frame, Duration, Easing) ->
    case Easing of
        linear ->
            lerp(Start, End_, Frame, Duration);

        ease_in ->
            ease_in(Start, End_, Frame, Duration);

        ease_out ->
            ease_out(Start, End_, Frame, Duration);

        ease_in_out ->
            ease_in_out(Start, End_, Frame, Duration)
    end.

-file("src/etui/anim.gleam", 158).
-spec find_segment(list(keyframe()), integer(), easing()) -> integer().
find_segment(Kfs, Frame, Easing) ->
    case Kfs of
        [] ->
            0;

        [{keyframe, _, V}] ->
            V;

        [{keyframe, At1, V1}, {keyframe, At2, V2} | Rest] ->
            case Frame < At2 of
                true ->
                    interpolate(V1, V2, Frame - At1, At2 - At1, Easing);

                false ->
                    find_segment([{keyframe, At2, V2} | Rest], Frame, Easing)
            end
    end.

-file("src/etui/anim.gleam", 153).
-spec sequence(list(keyframe()), integer(), easing()) -> integer().
-doc(~" Interpolate along a keyframe sequence at the given frame.
 Keyframes are sorted automatically, so order at the call site doesn't matter.
 Returns the last keyframe value if frame exceeds the sequence.").
sequence(Keyframes, Frame, Easing) ->
    Sorted = gleam@list:sort(Keyframes, fun(A, B) ->
        gleam@int:compare(erlang:element(2, A), erlang:element(2, B))
    end),
    find_segment(Sorted, Frame, Easing).

