-module(etui@color).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([lerp_rgb/4, hue_to_rgb/1, rainbow/2, gradient/3, pulse/3, scale/2]).

-file("src/etui/color.gleam", 13).
-spec lerp_rgb(etui@style:color(), etui@style:color(), integer(), integer()) -> etui@style:color().
-doc(~" Linear interpolation between two Rgb colors.
 For non-Rgb inputs, returns whichever endpoint is closer to t.").
lerp_rgb(A, B, T, Max) ->
    case {A, B} of
        {{rgb, R1, G1, B1}, {rgb, R2, G2, B2}} ->
            {rgb, etui@anim:lerp(R1, R2, T, Max), etui@anim:lerp(G1, G2, T, Max), etui@anim:lerp(B1, B2, T, Max)};

        {_, _} ->
            case (T * 2) < Max of
                true ->
                    A;

                false ->
                    B
            end
    end.

-file("src/etui/color.gleam", 39).
-spec hue_to_rgb(integer()) -> etui@style:color().
-doc(~" Convert a hue angle (0–359) to a fully-saturated Rgb color.
 Implements the HSV→RGB formula with S=1, V=1, integer arithmetic.").
hue_to_rgb(Hue) ->
    H = ((Hue rem 360) + 360) rem 360,
    Sector = H div 60,
    F = H rem 60,
    Up = (F * 255) div 60,
    Dn = ((60 - F) * 255) div 60,
    case Sector of
        0 ->
            {rgb, 255, Up, 0};

        1 ->
            {rgb, Dn, 255, 0};

        2 ->
            {rgb, 0, 255, Up};

        3 ->
            {rgb, 0, Dn, 255};

        4 ->
            {rgb, Up, 0, 255};

        _ ->
            {rgb, 255, 0, Dn}
    end.

-file("src/etui/color.gleam", 60).
-spec rainbow(integer(), integer()) -> etui@style:color().
-doc(~" Returns an Rgb color that cycles through the full hue spectrum
 with the given period in frames.").
rainbow(Frame, Period) ->
    P = gleam@int:max(1, Period),
    hue_to_rgb(case P of
        0 ->
            0;

        _value ->
            (etui@anim:cycle(Frame, P) * 360) div _value
    end).

-file("src/etui/color.gleam", 127).
-spec get_nth(list(etui@style:color()), integer()) -> etui@style:color().
get_nth(Colors, N) ->
    case Colors of
        [] ->
            default;

        [C | _] when N =< 0 ->
            C;

        [_ | Rest] ->
            get_nth(Rest, N - 1)
    end.

-file("src/etui/color.gleam", 71).
-spec gradient(list(etui@style:color()), integer(), integer()) -> etui@style:color().
-doc(~" Color at integer position `pos` within [0, max] across a list of
 color stops. Stops are distributed evenly. Lerps between adjacent
 stops. Requires Rgb stops for smooth blending; non-Rgb stops snap.").
gradient(Stops, Pos, Max) ->
    N = erlang:length(Stops),
    case N of
        0 ->
            default;

        1 ->
            case Stops of
                [C | _] ->
                    C;

                [] ->
                    default
            end;

        _ ->
            Segs = N - 1,
            Seg_size = gleam@int:max(1, case Segs of
                0 ->
                    0;

                _value ->
                    Max div _value
            end),
            Seg_idx = gleam@int:min(Segs - 1, case Seg_size of
                0 ->
                    0;

                _value@1 ->
                    Pos div _value@1
            end),
            Seg_pos = Pos - (Seg_idx * Seg_size),
            lerp_rgb(get_nth(Stops, Seg_idx), get_nth(Stops, Seg_idx + 1), Seg_pos, Seg_size)
    end.

-file("src/etui/color.gleam", 101).
-spec pulse(etui@style:color(), integer(), integer()) -> etui@style:color().
-doc(~" Oscillate an Rgb color between half and full brightness.
 Use `frame + x * phase_step` for a per-cell wave effect.
 Non-Rgb colors are returned unchanged.").
pulse(C, Frame, Period) ->
    case C of
        {rgb, R, G, B} ->
            Bright = etui@anim:oscillate(128, 255, Frame, gleam@int:max(1, Period)),
            {rgb, (R * Bright) div 255, (G * Bright) div 255, (B * Bright) div 255};

        _ ->
            C
    end.

-file("src/etui/color.gleam", 116).
-spec scale(etui@style:color(), integer()) -> etui@style:color().
-doc(~" Scale all RGB channels by `factor` / 255.
 factor=255 → unchanged, factor=128 → half brightness.").
scale(C, Factor) ->
    case C of
        {rgb, R, G, B} ->
            {rgb, (R * Factor) div 255, (G * Factor) div 255, (B * Factor) div 255};

        _ ->
            C
    end.

