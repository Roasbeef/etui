-module(etui@geometry).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([rect_new/4, rect_zero/0, right/1, bottom/1, area/1, contains/2, hit_test/3, intersect/2, union/2, inner/2, offset/3, clamp/2, size/1, rows/1, columns/1, resolve_sizes/2, split_with/5, split/3, split_h/2, split_v/2, centered_rect/3, percent_rect/3, split_with_spacing/4, split_responsive/2]).
-export_type([position/0, size/0, rect/0, direction/0, constraint/0, margin/0, slot/0, flex/0, breakpoint/0]).

-type position() :: {position, integer(), integer()}.

-type size() :: {size, integer(), integer()}.

-type rect() :: {rect, position(), size()}.

-type direction() :: horizontal | vertical.

-type constraint() :: {length, integer()} | {min, integer()} | {max, integer()} | {percentage, integer()} | {ratio, integer(), integer()} | fill | {fill_weighted, integer()}.

-type margin() :: {margin, integer(), integer()}.

-type slot() :: rigid | {slot, integer(), integer(), integer()}.

-type flex() :: flex_start | flex_end | flex_center | flex_between | flex_around | flex_evenly.

-type breakpoint() :: {breakpoint, integer(), list(constraint())}.

-file("src/etui/geometry.gleam", 63).
-spec rect_new(integer(), integer(), integer(), integer()) -> rect().
-doc(~" Create a Rect with clamped width/height to non-negative.").
rect_new(X, Y, Width, Height) ->
    {rect, {position, X, Y}, {size, gleam@int:max(0, Width), gleam@int:max(0, Height)}}.

-file("src/etui/geometry.gleam", 71).
-spec rect_zero() -> rect().
-doc(~" Zero-sized rect at origin.").
rect_zero() ->
    {rect, {position, 0, 0}, {size, 0, 0}}.

-file("src/etui/geometry.gleam", 79).
-spec right(rect()) -> integer().
-doc(~" X coordinate of the right edge (exclusive: x + width).").
right(Rect) ->
    erlang:element(2, erlang:element(2, Rect)) + erlang:element(2, erlang:element(3, Rect)).

-file("src/etui/geometry.gleam", 84).
-spec bottom(rect()) -> integer().
-doc(~" Y coordinate of the bottom edge (exclusive: y + height).").
bottom(Rect) ->
    erlang:element(3, erlang:element(2, Rect)) + erlang:element(3, erlang:element(3, Rect)).

-file("src/etui/geometry.gleam", 89).
-spec area(rect()) -> integer().
-doc(~" Area in cells.").
area(Rect) ->
    erlang:element(2, erlang:element(3, Rect)) * erlang:element(3, erlang:element(3, Rect)).

-file("src/etui/geometry.gleam", 94).
-spec contains(rect(), position()) -> boolean().
-doc(~" Check if a position is inside the rect (inclusive of edges).").
contains(Rect, Pos) ->
    (((erlang:element(2, Pos) >= erlang:element(2, erlang:element(2, Rect))) andalso (erlang:element(2, Pos) < right(Rect))) andalso (erlang:element(3, Pos) >= erlang:element(3, erlang:element(2, Rect)))) andalso (erlang:element(3, Pos) < bottom(Rect)).

-file("src/etui/geometry.gleam", 103).
-spec hit_test(rect(), integer(), integer()) -> boolean().
-doc(~" True if terminal cell `(x, y)` is inside `rect`.
 Convenience wrapper over `contains` for use with mouse event coordinates.").
hit_test(Rect, X, Y) ->
    contains(Rect, {position, X, Y}).

-file("src/etui/geometry.gleam", 108).
-spec intersect(rect(), rect()) -> {ok, rect()} | {error, nil}.
-doc(~" Intersection of two rects. Returns the overlapping rect if any.").
intersect(A, B) ->
    Left = gleam@int:max(erlang:element(2, erlang:element(2, A)), erlang:element(2, erlang:element(2, B))),
    Top = gleam@int:max(erlang:element(3, erlang:element(2, A)), erlang:element(3, erlang:element(2, B))),
    Right_edge = gleam@int:min(right(A), right(B)),
    Bottom_edge = gleam@int:min(bottom(A), bottom(B)),
    case (Left < Right_edge) andalso (Top < Bottom_edge) of
        true ->
            {ok, {rect, {position, Left, Top}, {size, Right_edge - Left, Bottom_edge - Top}}};

        false ->
            {error, nil}
    end.

-file("src/etui/geometry.gleam", 125).
-spec union(rect(), rect()) -> rect().
-doc(~" Union of two rects: smallest rect that contains both.").
union(A, B) ->
    Left = gleam@int:min(erlang:element(2, erlang:element(2, A)), erlang:element(2, erlang:element(2, B))),
    Top = gleam@int:min(erlang:element(3, erlang:element(2, A)), erlang:element(3, erlang:element(2, B))),
    Right_edge = gleam@int:max(right(A), right(B)),
    Bottom_edge = gleam@int:max(bottom(A), bottom(B)),
    {rect, {position, Left, Top}, {size, Right_edge - Left, Bottom_edge - Top}}.

-file("src/etui/geometry.gleam", 153).
-spec inner(rect(), margin()) -> rect().
-doc(~" Shrink a rect by `margin` on all four sides.

 Matches ratatui's `Rect::inner`: the origin always moves in by the margin,
 and the size saturates at zero when the rect is too small to hold it. The
 result can therefore sit outside the original rect once it has collapsed,
 which is the behaviour callers ported from ratatui expect.

 ```gleam
 geometry.inner(area, geometry.Margin(1, 1))  // one cell of padding
 ```").
inner(Rect, Margin) ->
    H = gleam@int:max(0, erlang:element(2, Margin)),
    V = gleam@int:max(0, erlang:element(3, Margin)),
    {rect, {position, erlang:element(2, erlang:element(2, Rect)) + H, erlang:element(3, erlang:element(2, Rect)) + V}, {size, gleam@int:max(0, erlang:element(2, erlang:element(3, Rect)) - (2 * H)), gleam@int:max(0, erlang:element(3, erlang:element(3, Rect)) - (2 * V))}}.

-file("src/etui/geometry.gleam", 166).
-spec offset(rect(), integer(), integer()) -> rect().
-doc(~" Translate a rect by `dx`, `dy`. Size is unchanged.").
offset(Rect, Dx, Dy) ->
    {rect, {position, erlang:element(2, erlang:element(2, Rect)) + Dx, erlang:element(3, erlang:element(2, Rect)) + Dy}, erlang:element(3, Rect)}.

-file("src/etui/geometry.gleam", 175).
-spec clamp(rect(), rect()) -> rect().
-doc(~" Move and shrink `rect` so it fits entirely inside `bounds`.
 Returns a zero-size rect when the two do not overlap at all.").
clamp(Rect, Bounds) ->
    W = gleam@int:min(erlang:element(2, erlang:element(3, Rect)), erlang:element(2, erlang:element(3, Bounds))),
    H = gleam@int:min(erlang:element(3, erlang:element(3, Rect)), erlang:element(3, erlang:element(3, Bounds))),
    X = gleam@int:clamp(erlang:element(2, erlang:element(2, Rect)), erlang:element(2, erlang:element(2, Bounds)), right(Bounds) - W),
    Y = gleam@int:clamp(erlang:element(3, erlang:element(2, Rect)), erlang:element(3, erlang:element(2, Bounds)), bottom(Bounds) - H),
    {rect, {position, X, Y}, {size, W, H}}.

-file("src/etui/geometry.gleam", 184).
-spec size(rect()) -> size().
-doc(~" The rect's size, dropping its position.").
size(Rect) ->
    erlang:element(3, Rect).

-file("src/etui/geometry.gleam", 213).
-spec indices_acc(integer(), list(integer())) -> list(integer()).
indices_acc(I, Acc) ->
    case I < 0 of
        true ->
            Acc;

        false ->
            indices_acc(I - 1, [I | Acc])
    end.

-file("src/etui/geometry.gleam", 209).
-spec indices(integer()) -> list(integer()).
indices(N) ->
    indices_acc(N - 1, []).

-file("src/etui/geometry.gleam", 189).
-spec rows(rect()) -> list(rect()).
-doc(~" One 1-cell-tall rect per row of `rect`, top to bottom.").
rows(Rect) ->
    gleam@list:map(indices(erlang:element(3, erlang:element(3, Rect))), fun(I) ->
        {rect, {position, erlang:element(2, erlang:element(2, Rect)), erlang:element(3, erlang:element(2, Rect)) + I}, {size, erlang:element(2, erlang:element(3, Rect)), 1}}
    end).

-file("src/etui/geometry.gleam", 199).
-spec columns(rect()) -> list(rect()).
-doc(~" One 1-cell-wide rect per column of `rect`, left to right.").
columns(Rect) ->
    gleam@list:map(indices(erlang:element(2, erlang:element(3, Rect))), fun(I) ->
        {rect, {position, erlang:element(2, erlang:element(2, Rect)) + I, erlang:element(3, erlang:element(2, Rect))}, {size, 1, erlang:element(3, erlang:element(3, Rect))}}
    end).

-file("src/etui/geometry.gleam", 687).
-spec pick_size(constraint(), list(integer()), list(integer()), list(integer()), list(integer())) -> integer().
pick_size(Constraint, Lengths, Pcts, Ratios, Flexes) ->
    case Constraint of
        {length, _} ->
            case Lengths of
                [H | _] ->
                    H;

                _ ->
                    0
            end;

        {percentage, _} ->
            case Pcts of
                [H@1 | _] ->
                    H@1;

                _ ->
                    0
            end;

        {ratio, _, _} ->
            case Ratios of
                [H@2 | _] ->
                    H@2;

                _ ->
                    0
            end;

        fill ->
            case Flexes of
                [H@3 | _] ->
                    H@3;

                _ ->
                    0
            end;

        {fill_weighted, _} ->
            case Flexes of
                [H@3 | _] ->
                    H@3;

                _ ->
                    0
            end;

        {min, _} ->
            case Flexes of
                [H@3 | _] ->
                    H@3;

                _ ->
                    0
            end;

        {max, _} ->
            case Flexes of
                [H@3 | _] ->
                    H@3;

                _ ->
                    0
            end
    end.

-file("src/etui/geometry.gleam", 654).
-spec assemble_sizes(list(constraint()), list(integer()), list(integer()), list(integer()), list(integer()), list(integer())) -> list(integer()).
assemble_sizes(Constraints, Length_sizes, Pct_sizes, Ratio_sizes, Flex_sizes, Acc) ->
    case Constraints of
        [] ->
            lists:reverse(Acc);

        [C | Cs] ->
            Size = pick_size(C, Length_sizes, Pct_sizes, Ratio_sizes, Flex_sizes),
            Ls = case Length_sizes of
                [_ | T] ->
                    T;

                _ ->
                    []
            end,
            Ps = case Pct_sizes of
                [_ | T@1] ->
                    T@1;

                _ ->
                    []
            end,
            Rs = case Ratio_sizes of
                [_ | T@2] ->
                    T@2;

                _ ->
                    []
            end,
            Fs = case Flex_sizes of
                [_ | T@3] ->
                    T@3;

                _ ->
                    []
            end,
            assemble_sizes(Cs, Ls, Ps, Rs, Fs, [Size | Acc])
    end.

-file("src/etui/geometry.gleam", 636).
-spec merge_shares(list({ok, integer()} | {error, nil}), list(integer())) -> list(integer()).
merge_shares(Frozen, Shares) ->
    case {Frozen, Shares} of
        {[{ok, N} | F_rest], [_ | S_rest]} ->
            [N | merge_shares(F_rest, S_rest)];

        {[{error, nil} | F_rest@1], [S | S_rest@1]} ->
            [S | merge_shares(F_rest@1, S_rest@1)];

        {_, _} ->
            []
    end.

-file("src/etui/geometry.gleam", 614).
-spec clamp_loop(list(slot()), list({ok, integer()} | {error, nil}), list(integer()), list({ok, integer()} | {error, nil})) -> list({ok, integer()} | {error, nil}).
clamp_loop(Slots, Frozen, Shares, Acc) ->
    case {Slots, Frozen, Shares} of
        {[{slot, _, Lo, Hi} | S_rest], [{error, nil} | F_rest], [S | Sh_rest]} ->
            Entry = case {S < Lo, S > Hi} of
                {true, _} ->
                    {ok, Lo};

                {_, true} ->
                    {ok, Hi};

                {_, _} ->
                    {error, nil}
            end,
            clamp_loop(S_rest, F_rest, Sh_rest, [Entry | Acc]);

        {[_ | S_rest@1], [F | F_rest@1], [_ | Sh_rest@1]} ->
            clamp_loop(S_rest@1, F_rest@1, Sh_rest@1, [F | Acc]);

        {_, _, _} ->
            lists:reverse(Acc)
    end.

-file("src/etui/geometry.gleam", 602).
-spec clamp_round(list(slot()), list({ok, integer()} | {error, nil}), list(integer())) -> {ok, list({ok, integer()} | {error, nil})} | {error, nil}.
clamp_round(Slots, Frozen, Shares) ->
    Next = clamp_loop(Slots, Frozen, Shares, []),
    case Next =:= Frozen of
        true ->
            {error, nil};

        false ->
            {ok, Next}
    end.

-file("src/etui/geometry.gleam", 580).
-spec spread_remainder(list(slot()), list({ok, integer()} | {error, nil}), list(integer()), integer(), list(integer())) -> list(integer()).
spread_remainder(Slots, Frozen, Bases, Extra, Acc) ->
    case {Slots, Frozen, Bases} of
        {[{slot, W, _, _} | S_rest], [{error, nil} | F_rest], [B | B_rest]} ->
            case (W > 0) andalso (Extra > 0) of
                true ->
                    spread_remainder(S_rest, F_rest, B_rest, Extra - 1, [B + 1 | Acc]);

                false ->
                    spread_remainder(S_rest, F_rest, B_rest, Extra, [B | Acc])
            end;

        {[_ | S_rest@1], [_ | F_rest@1], [B@1 | B_rest@1]} ->
            spread_remainder(S_rest@1, F_rest@1, B_rest@1, Extra, [B@1 | Acc]);

        {_, _, _} ->
            lists:reverse(Acc)
    end.

-file("src/etui/geometry.gleam", 561).
-spec base_shares(list(slot()), list({ok, integer()} | {error, nil}), integer(), integer(), list(integer())) -> list(integer()).
base_shares(Slots, Frozen, Remaining, Total_weight, Acc) ->
    case {Slots, Frozen} of
        {[{slot, W, _, _} | S_rest], [{error, nil} | F_rest]} ->
            base_shares(S_rest, F_rest, Remaining, Total_weight, [case Total_weight of
                0 ->
                    0;

                _value ->
                    (Remaining * W) div _value
            end | Acc]);

        {[_ | S_rest@1], [_ | F_rest@1]} ->
            base_shares(S_rest@1, F_rest@1, Remaining, Total_weight, [0 | Acc]);

        {_, _} ->
            lists:reverse(Acc)
    end.

-file("src/etui/geometry.gleam", 550).
-spec open_shares(list(slot()), list({ok, integer()} | {error, nil}), integer(), integer()) -> list(integer()).
open_shares(Slots, Frozen, Remaining, Total_weight) ->
    Bases = base_shares(Slots, Frozen, Remaining, Total_weight, []),
    Claimed = gleam@list:fold(Bases, 0, fun(A, B) ->
        A + B
    end),
    spread_remainder(Slots, Frozen, Bases, Remaining - Claimed, []).

-file("src/etui/geometry.gleam", 647).
-spec unwrap_size({ok, integer()} | {error, nil}) -> integer().
unwrap_size(F) ->
    case F of
        {ok, N} ->
            N;

        {error, nil} ->
            0
    end.

-file("src/etui/geometry.gleam", 538).
-spec open_weight_of(list(slot()), list({ok, integer()} | {error, nil})) -> integer().
open_weight_of(Slots, Frozen) ->
    case {Slots, Frozen} of
        {[{slot, W, _, _} | S_rest], [{error, nil} | F_rest]} ->
            W + open_weight_of(S_rest, F_rest);

        {[_ | S_rest@1], [_ | F_rest@1]} ->
            open_weight_of(S_rest@1, F_rest@1);

        {_, _} ->
            0
    end.

-file("src/etui/geometry.gleam", 510).
-spec settle(list(slot()), list({ok, integer()} | {error, nil}), integer(), integer()) -> list(integer()).
settle(Slots, Frozen, Budget, Fuel) ->
    Taken = gleam@list:fold(Frozen, 0, fun(Acc, F) ->
        case F of
            {ok, N} ->
                Acc + N;

            {error, nil} ->
                Acc
        end
    end),
    Remaining = gleam@int:max(0, Budget - Taken),
    Open_weight = open_weight_of(Slots, Frozen),
    case (Open_weight =< 0) orelse (Fuel =< 0) of
        true ->
            gleam@list:map(Frozen, fun unwrap_size/1);

        false ->
            Shares = open_shares(Slots, Frozen, Remaining, Open_weight),
            case clamp_round(Slots, Frozen, Shares) of
                {error, nil} ->
                    merge_shares(Frozen, Shares);

                {ok, Next} ->
                    settle(Slots, Next, Budget, Fuel - 1)
            end
    end.

-file("src/etui/geometry.gleam", 415).
-spec phase_proportional(list(integer()), integer(), integer(), integer(), integer(), list(integer())) -> {list(integer()), integer()}.
phase_proportional(Demands, Budget, Total_demand, Cumsum, Prev_target, Acc) ->
    case Demands of
        [] ->
            {lists:reverse(Acc), Prev_target};

        [D | Rest] ->
            New_cumsum = Cumsum + D,
            Target = case Total_demand of
                0 ->
                    0;

                _ ->
                    case Total_demand =< Budget of
                        true ->
                            New_cumsum;

                        false ->
                            case Total_demand of
                                0 ->
                                    0;

                                _value ->
                                    (Budget * New_cumsum) div _value
                            end
                    end
            end,
            Size = Target - Prev_target,
            phase_proportional(Rest, Budget, Total_demand, New_cumsum, Target, [Size | Acc])
    end.

-file("src/etui/geometry.gleam", 499).
-spec fit_to_budget(list(integer()), integer()) -> list(integer()).
fit_to_budget(Sizes, Budget) ->
    Total = gleam@list:fold(Sizes, 0, fun(A, B) ->
        A + B
    end),
    case Total > Budget of
        false ->
            Sizes;

        true ->
            {Fitted, _} = phase_proportional(Sizes, Budget, Total, 0, 0, []),
            Fitted
    end.

-file("src/etui/geometry.gleam", 452).
-spec slot_of(constraint(), integer()) -> slot().
slot_of(C, Budget) ->
    case C of
        fill ->
            {slot, 1, 0, Budget};

        {fill_weighted, W} ->
            {slot, gleam@int:max(0, W), 0, Budget};

        {min, N} ->
            {slot, 1, gleam@int:clamp(N, 0, Budget), Budget};

        {max, N@1} ->
            {slot, 1, 0, gleam@int:clamp(N@1, 0, Budget)};

        _ ->
            rigid
    end.

-file("src/etui/geometry.gleam", 479).
-spec phase_flex(list(constraint()), integer()) -> list(integer()).
phase_flex(Constraints, Budget) ->
    Slots = gleam@list:map(Constraints, fun(_capture) ->
        slot_of(_capture, Budget)
    end),
    Frozen = gleam@list:map(Slots, fun(S) ->
        case S of
            rigid ->
                {ok, 0};

            {slot, _, _, _} ->
                {error, nil}
        end
    end),
    fit_to_budget(settle(Slots, Frozen, Budget, erlang:length(Slots) + 1), Budget).

-file("src/etui/geometry.gleam", 375).
-spec gcd(integer(), integer()) -> integer().
gcd(A, B) ->
    case B of
        0 ->
            A;

        _ ->
            gcd(B, case B of
                0 ->
                    0;

                _value ->
                    A rem _value
            end)
    end.

-file("src/etui/geometry.gleam", 367).
-spec reduce(integer(), integer()) -> {integer(), integer()}.
reduce(N, D) ->
    G = gcd(gleam@int:absolute_value(N), gleam@int:absolute_value(D)),
    case G of
        0 ->
            {N, D};

        _ ->
            {case G of
                0 ->
                    0;

                _value ->
                    N div _value
            end, case G of
                0 ->
                    0;

                _value@1 ->
                    D div _value@1
            end}
    end.

-file("src/etui/geometry.gleam", 344).
-spec ratio_targets(list(constraint()), integer(), integer(), integer(), integer(), list(integer())) -> list(integer()).
ratio_targets(Constraints, Total, Num, Den, Prev_target, Acc) ->
    case Constraints of
        [] ->
            lists:reverse(Acc);

        [{ratio, A, B} | Rest] ->
            case (B =:= 0) orelse (A =< 0) of
                true ->
                    ratio_targets(Rest, Total, Num, Den, Prev_target, [0 | Acc]);

                false ->
                    {N, D} = reduce((Num * B) + (A * Den), Den * B),
                    Target = case D of
                        0 ->
                            0;

                        _value ->
                            (Total * N) div _value
                    end,
                    ratio_targets(Rest, Total, N, D, Target, [Target - Prev_target | Acc])
            end;

        [_ | Rest@1] ->
            ratio_targets(Rest@1, Total, Num, Den, Prev_target, [0 | Acc])
    end.

-file("src/etui/geometry.gleam", 384).
-spec phase_percentage(list(constraint()), integer(), integer(), integer(), integer(), list(integer())) -> {list(integer()), integer()}.
phase_percentage(Constraints, Denom, Base, Acc_pct, Prev_target, Acc) ->
    case Constraints of
        [] ->
            {lists:reverse(Acc), Prev_target};

        [C | Rest] ->
            {Size, New_acc, New_target} = case C of
                {percentage, P} ->
                    New_acc_pct = Acc_pct + P,
                    Target = case Denom of
                        0 ->
                            0;

                        _ ->
                            case Denom of
                                0 ->
                                    0;

                                _value ->
                                    (Base * New_acc_pct) div _value
                            end
                    end,
                    S = Target - Prev_target,
                    {S, New_acc_pct, Target};

                _ ->
                    {0, Acc_pct, Prev_target}
            end,
            phase_percentage(Rest, Denom, Base, New_acc, New_target, [Size | Acc])
    end.

-file("src/etui/geometry.gleam", 311).
-spec phase_length(list(constraint()), integer(), integer(), list(integer())) -> {list(integer()), integer()}.
phase_length(Constraints, Total, Used, Acc) ->
    case Constraints of
        [] ->
            {lists:reverse(Acc), Used};

        [C | Rest] ->
            {Size, New_used} = case C of
                {length, V} ->
                    Take = gleam@int:min(V, gleam@int:max(0, Total - Used)),
                    {Take, Used + Take};

                _ ->
                    {0, Used}
            end,
            phase_length(Rest, Total, New_used, [Size | Acc])
    end.

-file("src/etui/geometry.gleam", 260).
-spec resolve_sizes_impl(integer(), list(constraint())) -> list(integer()).
resolve_sizes_impl(Total, Constraints) ->
    {Length_sizes, Length_used} = phase_length(Constraints, Total, 0, []),
    Prop_budget = gleam@int:max(0, Total - Length_used),
    Pct_total_pct = gleam@list:fold(Constraints, 0, fun(Acc, C) ->
        case C of
            {percentage, P} ->
                Acc + P;

            _ ->
                Acc
        end
    end),
    {Denom, Pct_base} = case (Total * Pct_total_pct) > (Prop_budget * 100) of
        true ->
            {Pct_total_pct, Prop_budget};

        false ->
            {100, Total}
    end,
    {Pct_sizes, Pct_used} = phase_percentage(Constraints, Denom, Pct_base, 0, 0, []),
    Ratio_budget = gleam@int:max(0, Prop_budget - Pct_used),
    Ratio_demands = ratio_targets(Constraints, Total, 0, 1, 0, []),
    Total_ratio_demand = gleam@list:fold(Ratio_demands, 0, fun(Acc, D) ->
        Acc + D
    end),
    {Ratio_sizes, Ratio_used} = phase_proportional(Ratio_demands, Ratio_budget, Total_ratio_demand, 0, 0, []),
    Flex_budget = gleam@int:max(0, ((Total - Length_used) - Pct_used) - Ratio_used),
    Flex_sizes = phase_flex(Constraints, Flex_budget),
    assemble_sizes(Constraints, Length_sizes, Pct_sizes, Ratio_sizes, Flex_sizes, []).

-file("src/etui/geometry.gleam", 253).
-spec resolve_sizes(integer(), list(constraint())) -> list(integer()).
-doc(~" Distribute total space among constraints.

 Returns a list of sizes (one per constraint) that sum to ≤ total.
 Sum equals total when Fill (or Min/Max) is present or constraints saturate.

 Algorithm (three-phase Discrete Cumulative Allocation):
 1. Length, exact, allocated first. Clamped to remaining budget in order.
 2. Percentage + Ratio, proportional from total. Cumulative to prevent jitter.
    Scaled proportionally if combined demand exceeds available budget.
 3. Fill, FillWeighted, Min and Max share the remainder by weight, bounded
    by their floors and ceilings. When the bounds cannot all be met the
    sizes are scaled to fit rather than over-allocated: the result always
    fits the area it was asked to fill.

 ## Stability under resize

 With `Length`, `Percentage`, `Fill` and `FillWeighted`, growing the area by
 a cell never moves a boundary backwards, so a resize does not make panels
 jitter.

 `Min`, `Max` and `Ratio` do not guarantee that. A slot pinned at its floor
 competes in a smaller pool than a free one, so the size at which it stops
 being pinned is a step rather than a slope and its neighbours resize
 sharply across it. `Ratio` accumulates its fractions rather than rounding
 each one separately, which removes the worst of its own jitter but not all
 of it. Measured over 12000 random layouts the three together affect about
 0.2% of them, by a few cells.

 If a layout is resized interactively and must not jitter, express it with
 `Percentage` or `FillWeighted`.").
resolve_sizes(Total, Constraints) ->
    case Total < 0 of
        true ->
            gleam@list:map(Constraints, fun(_) ->
                0
            end);

        false ->
            resolve_sizes_impl(Total, Constraints)
    end.

-file("src/etui/geometry.gleam", 909).
-spec offsets_loop(list(integer()), list(integer()), integer(), integer(), list(integer())) -> list(integer()).
offsets_loop(Sizes, Leads, Gap, Cursor, Acc) ->
    case {Sizes, Leads} of
        {[S | S_rest], [Lead | L_rest]} ->
            Start = Cursor + Lead,
            offsets_loop(S_rest, L_rest, Gap, (Start + S) + Gap, [Start | Acc]);

        {_, _} ->
            lists:reverse(Acc)
    end.

-file("src/etui/geometry.gleam", 905).
-spec flex_offsets(list(integer()), list(integer()), integer()) -> list(integer()).
flex_offsets(Sizes, Leads, Gap) ->
    offsets_loop(Sizes, Leads, Gap, 0, []).

-file("src/etui/geometry.gleam", 848).
-spec axis_length(direction(), rect()) -> integer().
axis_length(Direction, Area) ->
    case Direction of
        vertical ->
            erlang:element(3, erlang:element(3, Area));

        horizontal ->
            erlang:element(2, erlang:element(3, Area))
    end.

-file("src/etui/geometry.gleam", 934).
-spec rects_loop(direction(), rect(), list(integer()), list(integer()), integer(), list(rect())) -> list(rect()).
rects_loop(Direction, Area, Sizes, Offsets, Limit, Acc) ->
    case {Sizes, Offsets} of
        {[Size | S_rest], [Offset | O_rest]} ->
            Start = gleam@int:clamp(Offset, 0, Limit),
            Clamped = gleam@int:min(Size, Limit - Start),
            Rect = case Direction of
                vertical ->
                    {rect, {position, erlang:element(2, erlang:element(2, Area)), erlang:element(3, erlang:element(2, Area)) + Start}, {size, erlang:element(2, erlang:element(3, Area)), Clamped}};

                horizontal ->
                    {rect, {position, erlang:element(2, erlang:element(2, Area)) + Start, erlang:element(3, erlang:element(2, Area))}, {size, Clamped, erlang:element(3, erlang:element(3, Area))}}
            end,
            rects_loop(Direction, Area, S_rest, O_rest, Limit, [Rect | Acc]);

        {_, _} ->
            lists:reverse(Acc)
    end.

-file("src/etui/geometry.gleam", 925).
-spec build_flex_rects(direction(), rect(), list(integer()), list(integer())) -> list(rect()).
build_flex_rects(Direction, Area, Sizes, Offsets) ->
    rects_loop(Direction, Area, Sizes, Offsets, axis_length(Direction, Area), []).

-file("src/etui/geometry.gleam", 889).
-spec spread_gap(list(integer()), list(integer()), integer(), list(integer())) -> list(integer()).
spread_gap(Weights, Bases, Extra, Acc) ->
    case {Weights, Bases} of
        {[W | W_rest], [B | B_rest]} ->
            case (W > 0) andalso (Extra > 0) of
                true ->
                    spread_gap(W_rest, B_rest, Extra - 1, [B + 1 | Acc]);

                false ->
                    spread_gap(W_rest, B_rest, Extra, [B | Acc])
            end;

        {_, _} ->
            lists:reverse(Acc)
    end.

-file("src/etui/geometry.gleam", 859).
-spec gap_weights(flex(), integer()) -> list(integer()).
gap_weights(Flex, N) ->
    Inner = gleam@int:max(0, N - 1),
    case Flex of
        flex_start ->
            lists:append(gleam@list:repeat(0, N), [1]);

        flex_end ->
            [1 | gleam@list:repeat(0, N)];

        flex_center ->
            [1 | lists:append(gleam@list:repeat(0, Inner), [1])];

        flex_between ->
            [0 | lists:append(gleam@list:repeat(1, Inner), [0])];

        flex_around ->
            [1 | lists:append(gleam@list:repeat(2, Inner), [1])];

        flex_evenly ->
            gleam@list:repeat(1, N + 1)
    end.

-file("src/etui/geometry.gleam", 873).
-spec flex_leads(flex(), integer(), integer()) -> list(integer()).
flex_leads(Flex, N, Leftover) ->
    Weights = gap_weights(Flex, N),
    Total = gleam@list:fold(Weights, 0, fun(A, B) ->
        A + B
    end),
    case Total =< 0 of
        true ->
            gleam@list:repeat(0, N);

        false ->
            Bases = gleam@list:map(Weights, fun(W) ->
                case Total of
                    0 ->
                        0;

                    _value ->
                        (Leftover * W) div _value
                end
            end),
            Claimed = gleam@list:fold(Bases, 0, fun(A, B) ->
                A + B
            end),
            _pipe = spread_gap(Weights, Bases, Leftover - Claimed, []),
            gleam@list:take(_pipe, N)
    end.

-file("src/etui/geometry.gleam", 826).
-spec split_with(direction(), rect(), list(constraint()), flex(), integer()) -> list(rect()).
-doc(~" Split a rect with both a fixed gap between children and a rule for the
 space nobody claimed. This is the general form; `split`, `split_h`,
 `split_v` and `split_with_spacing` are all this function with some
 arguments filled in.

 `spacing` is a gap that always sits between children and is taken out of
 the budget before the constraints are resolved. `flex` then places whatever
 the constraints did not claim. The two compose: `FlexBetween` with a
 spacing of 2 keeps at least two cells between children and spreads the rest
 on top of that.

 ```gleam
 // Toolbar: fixed buttons pushed to the edges, at least 1 cell apart
 split_with(Horizontal, area, [Length(8), Length(8)], FlexBetween, 1)

 // A 20-wide dialog centred in the area
 split_with(Horizontal, area, [Length(20)], FlexCenter, 0)
 ```").
split_with(Direction, Area, Constraints, Flex, Spacing) ->
    N = erlang:length(Constraints),
    case N =:= 0 of
        true ->
            [];

        false ->
            Total = axis_length(Direction, Area),
            Gap = gleam@int:max(0, Spacing),
            Gap_cells = Gap * (N - 1),
            Sizes = resolve_sizes(gleam@int:max(0, Total - Gap_cells), Constraints),
            Claimed = gleam@list:fold(Sizes, 0, fun(Acc, S) ->
                Acc + S
            end) + Gap_cells,
            Leads = flex_leads(Flex, N, gleam@int:max(0, Total - Claimed)),
            build_flex_rects(Direction, Area, Sizes, flex_offsets(Sizes, Leads, Gap))
    end.

-file("src/etui/geometry.gleam", 758).
-spec split(direction(), rect(), list(constraint())) -> list(rect()).
-doc(~" Split a rect along a direction by applying constraints.").
split(Direction, Area, Constraints) ->
    split_with(Direction, Area, Constraints, flex_start, 0).

-file("src/etui/geometry.gleam", 722).
-spec split_h(rect(), list(constraint())) -> list(rect()).
-doc(~" Split horizontally (columns side-by-side). Shorthand for `split(Horizontal, ...)`.").
split_h(Area, Constraints) ->
    split(horizontal, Area, Constraints).

-file("src/etui/geometry.gleam", 727).
-spec split_v(rect(), list(constraint())) -> list(rect()).
-doc(~" Split vertically (rows stacked). Shorthand for `split(Vertical, ...)`.").
split_v(Area, Constraints) ->
    split(vertical, Area, Constraints).

-file("src/etui/geometry.gleam", 737).
-spec centered_rect(integer(), integer(), rect()) -> rect().
-doc(~" Center a rect of `width × height` within `area`.
 Clamps to area bounds. Common for popup placement.

 ```gleam
 let popup_area = geometry.centered_rect(60, 20, screen)
 ```").
centered_rect(Width, Height, Area) ->
    W = gleam@int:min(Width, erlang:element(2, erlang:element(3, Area))),
    H = gleam@int:min(Height, erlang:element(3, erlang:element(3, Area))),
    X = erlang:element(2, erlang:element(2, Area)) + ((erlang:element(2, erlang:element(3, Area)) - W) div 2),
    Y = erlang:element(3, erlang:element(2, Area)) + ((erlang:element(3, erlang:element(3, Area)) - H) div 2),
    {rect, {position, X, Y}, {size, W, H}}.

-file("src/etui/geometry.gleam", 751).
-spec percent_rect(integer(), integer(), rect()) -> rect().
-doc(~" Center a rect sized as a percentage of `area` (`pct_w` and `pct_h` are 0–100).
 Useful for responsive popup sizing:

 ```gleam
 let popup_area = geometry.percent_rect(60, 40, screen)  // 60% wide, 40% tall
 ```").
percent_rect(Pct_w, Pct_h, Area) ->
    W = (erlang:element(2, erlang:element(3, Area)) * gleam@int:clamp(Pct_w, 0, 100)) div 100,
    H = (erlang:element(3, erlang:element(3, Area)) * gleam@int:clamp(Pct_h, 0, 100)) div 100,
    centered_rect(W, H, Area).

-file("src/etui/geometry.gleam", 773).
-spec split_with_spacing(direction(), rect(), list(constraint()), integer()) -> list(rect()).
-doc(~" Split a rect with `spacing` cells of gap between each child.
 Gap cells are taken from the total before distributing to constraints.

 ```gleam
 // Two columns with a 1-cell gap
 split_with_spacing(Horizontal, area, [Fill, Fill], 1)
 ```").
split_with_spacing(Direction, Area, Constraints, Spacing) ->
    split_with(Direction, Area, Constraints, flex_start, Spacing).

-file("src/etui/geometry.gleam", 1002).
-spec pick_breakpoint(list(breakpoint()), integer()) -> list(constraint()).
pick_breakpoint(Sorted_desc, Width) ->
    case Sorted_desc of
        [] ->
            [];

        [Bp] ->
            erlang:element(3, Bp);

        [Bp@1 | Rest] ->
            case Width >= erlang:element(2, Bp@1) of
                true ->
                    erlang:element(3, Bp@1);

                false ->
                    pick_breakpoint(Rest, Width)
            end
    end.

-file("src/etui/geometry.gleam", 985).
-spec split_responsive(rect(), list(breakpoint())) -> list(rect()).
-doc(~" Split `area` horizontally using the first breakpoint whose `min_width` <=
 `area.size.width`, evaluated in descending order. Falls back to the last
 breakpoint (assumed smallest). Returns `[area]` if `breakpoints` is empty.

 Example, two columns on wide screens, stacked on narrow:
 ```gleam
 geometry.split_responsive(area, [
   geometry.Breakpoint(80, [Percentage(50), Percentage(50)]),
   geometry.Breakpoint(0,  [Percentage(100)]),
 ])
 ```").
split_responsive(Area, Breakpoints) ->
    case Breakpoints of
        [] ->
            [Area];

        _ ->
            Sorted = gleam@list:sort(Breakpoints, fun(A, B) ->
                gleam@int:compare(erlang:element(2, B), erlang:element(2, A))
            end),
            Chosen = pick_breakpoint(Sorted, erlang:element(2, erlang:element(3, Area))),
            split_h(Area, Chosen)
    end.

