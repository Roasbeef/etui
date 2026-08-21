-module(etui@widgets@scroll_view).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([scroll_view_new/2, sv_state_new/0, scroll_to/3, scroll_down/2, scroll_up/2, scroll_right/2, scroll_left/2, clamp/4, render/5, scroll_pct_y/3, scroll_pct_x/3]).
-export_type([scroll_view/0, scroll_view_state/0]).

-type scroll_view() :: {scroll_view, integer(), integer()}.

-type scroll_view_state() :: {scroll_view_state, integer(), integer()}.

-file("src/etui/widgets/scroll_view.gleam", 39).
-spec scroll_view_new(integer(), integer()) -> scroll_view().
scroll_view_new(Virtual_width, Virtual_height) ->
    {scroll_view, gleam@int:max(1, Virtual_width), gleam@int:max(1, Virtual_height)}.

-file("src/etui/widgets/scroll_view.gleam", 46).
-spec sv_state_new() -> scroll_view_state().
sv_state_new() ->
    {scroll_view_state, 0, 0}.

-file("src/etui/widgets/scroll_view.gleam", 50).
-spec scroll_to(scroll_view_state(), integer(), integer()) -> scroll_view_state().
scroll_to(_, X, Y) ->
    {scroll_view_state, gleam@int:max(0, X), gleam@int:max(0, Y)}.

-file("src/etui/widgets/scroll_view.gleam", 54).
-spec scroll_down(scroll_view_state(), integer()) -> scroll_view_state().
scroll_down(State, Lines) ->
    {scroll_view_state, erlang:element(2, State), erlang:element(3, State) + gleam@int:max(0, Lines)}.

-file("src/etui/widgets/scroll_view.gleam", 58).
-spec scroll_up(scroll_view_state(), integer()) -> scroll_view_state().
scroll_up(State, Lines) ->
    {scroll_view_state, erlang:element(2, State), gleam@int:max(0, erlang:element(3, State) - Lines)}.

-file("src/etui/widgets/scroll_view.gleam", 62).
-spec scroll_right(scroll_view_state(), integer()) -> scroll_view_state().
scroll_right(State, Cols) ->
    {scroll_view_state, erlang:element(2, State) + gleam@int:max(0, Cols), erlang:element(3, State)}.

-file("src/etui/widgets/scroll_view.gleam", 66).
-spec scroll_left(scroll_view_state(), integer()) -> scroll_view_state().
scroll_left(State, Cols) ->
    {scroll_view_state, gleam@int:max(0, erlang:element(2, State) - Cols), erlang:element(3, State)}.

-file("src/etui/widgets/scroll_view.gleam", 71).
-spec clamp(scroll_view_state(), scroll_view(), integer(), integer()) -> scroll_view_state().
-doc(~" Clamp scroll offsets so the viewport never goes past the virtual canvas.").
clamp(State, Sv, Visible_w, Visible_h) ->
    Max_x = gleam@int:max(0, erlang:element(2, Sv) - Visible_w),
    Max_y = gleam@int:max(0, erlang:element(3, Sv) - Visible_h),
    {scroll_view_state, gleam@int:min(erlang:element(2, State), Max_x), gleam@int:min(erlang:element(3, State), Max_y)}.

-file("src/etui/widgets/scroll_view.gleam", 93).
-spec render(etui@buffer:buffer(), etui@geometry:rect(), scroll_view(), scroll_view_state(), fun((etui@buffer:buffer(), etui@geometry:rect()) -> etui@buffer:buffer())) -> etui@buffer:buffer().
-doc(~" Render the scroll view.

 `render_inner` is called with a virtual buffer sized to
 `(sv.virtual_width × sv.virtual_height)`. The visible window at
 `(state.scroll_x, state.scroll_y)` is then blitted into `buf` at `area`.").
render(Buf, Area, Sv, State, Render_inner) ->
    case (erlang:element(2, erlang:element(3, Area)) =< 0) orelse (erlang:element(3, erlang:element(3, Area)) =< 0) of
        true ->
            Buf;

        false ->
            Virtual_area = etui@geometry:rect_new(0, 0, erlang:element(2, Sv), erlang:element(3, Sv)),
            Virtual_buf = begin
                _pipe = etui@buffer:buffer_new(Virtual_area),
                Render_inner(_pipe, Virtual_area)
            end,
            Window = etui@geometry:rect_new(gleam@int:max(0, erlang:element(2, State)), gleam@int:max(0, erlang:element(3, State)), erlang:element(2, erlang:element(3, Area)), erlang:element(3, erlang:element(3, Area))),
            etui@buffer:blit(Buf, Virtual_buf, Window, erlang:element(2, Area))
    end.

-file("src/etui/widgets/scroll_view.gleam", 126).
-spec scroll_pct_y(scroll_view_state(), scroll_view(), integer()) -> integer().
-doc(~" How far into the virtual canvas is the viewport (0.0–1.0 × 100).
 Returns an integer percentage (0–100). Useful for driving scrollbar widgets.").
scroll_pct_y(State, Sv, Visible_h) ->
    Max_scroll = gleam@int:max(1, erlang:element(3, Sv) - Visible_h),
    gleam@int:min(100, case Max_scroll of
        0 ->
            0;

        _value ->
            (erlang:element(3, State) * 100) div _value
    end).

-file("src/etui/widgets/scroll_view.gleam", 135).
-spec scroll_pct_x(scroll_view_state(), scroll_view(), integer()) -> integer().
scroll_pct_x(State, Sv, Visible_w) ->
    Max_scroll = gleam@int:max(1, erlang:element(2, Sv) - Visible_w),
    gleam@int:min(100, case Max_scroll of
        0 ->
            0;

        _value ->
            (erlang:element(2, State) * 100) div _value
    end).

