-module(etui@widgets@statusbar).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([statusbar_new/0, with_left/2, with_center/2, with_right/2, with_style/3, with_colors/3, render/3]).
-export_type([status_bar/0]).

-type status_bar() :: {status_bar, list(etui@span:line()), list(etui@span:line()), list(etui@span:line()), etui@style:color(), etui@style:color()}.

-file("src/etui/widgets/statusbar.gleam", 39).
-spec statusbar_new() -> status_bar().
-doc(~" New status bar with empty sections and default colors.").
statusbar_new() ->
    {status_bar, [], [], [], default, default}.

-file("src/etui/widgets/statusbar.gleam", 50).
-spec with_left(status_bar(), list(etui@span:line())) -> status_bar().
-doc(~" Set left section spans.").
with_left(Sb, Lines) ->
    {status_bar, Lines, erlang:element(3, Sb), erlang:element(4, Sb), erlang:element(5, Sb), erlang:element(6, Sb)}.

-file("src/etui/widgets/statusbar.gleam", 55).
-spec with_center(status_bar(), list(etui@span:line())) -> status_bar().
-doc(~" Set center section spans.").
with_center(Sb, Lines) ->
    {status_bar, erlang:element(2, Sb), Lines, erlang:element(4, Sb), erlang:element(5, Sb), erlang:element(6, Sb)}.

-file("src/etui/widgets/statusbar.gleam", 60).
-spec with_right(status_bar(), list(etui@span:line())) -> status_bar().
-doc(~" Set right section spans.").
with_right(Sb, Lines) ->
    {status_bar, erlang:element(2, Sb), erlang:element(3, Sb), Lines, erlang:element(5, Sb), erlang:element(6, Sb)}.

-file("src/etui/widgets/statusbar.gleam", 65).
-spec with_style(status_bar(), etui@style:color(), etui@style:color()) -> status_bar().
-doc(~" Set foreground and background colors for the bar background.").
with_style(Sb, Fg, Bg) ->
    {status_bar, erlang:element(2, Sb), erlang:element(3, Sb), erlang:element(4, Sb), Fg, Bg}.

-file("src/etui/widgets/statusbar.gleam", 73).
-spec with_colors(status_bar(), etui@style:color(), etui@style:color()) -> status_bar().
with_colors(Sb, Fg, Bg) ->
    {status_bar, erlang:element(2, Sb), erlang:element(3, Sb), erlang:element(4, Sb), Fg, Bg}.

-file("src/etui/widgets/statusbar.gleam", 159).
-spec inherit_bar_style(etui@span:line(), status_bar()) -> etui@span:line().
inherit_bar_style(Line, Sb) ->
    etui@span:line_aligned(gleam@list:map(erlang:element(2, Line), fun(Sp) ->
        Fg = case erlang:element(2, erlang:element(3, Sp)) of
            default ->
                erlang:element(5, Sb);

            _ ->
                erlang:element(2, erlang:element(3, Sp))
        end,
        Bg = case erlang:element(3, erlang:element(3, Sp)) of
            default ->
                erlang:element(6, Sb);

            _ ->
                erlang:element(3, erlang:element(3, Sp))
        end,
        {span, erlang:element(2, Sp), etui@style:with_bg(etui@style:with_fg(erlang:element(3, Sp), Fg), Bg), erlang:element(4, Sp)}
    end), erlang:element(3, Line)).

-file("src/etui/widgets/statusbar.gleam", 132).
-spec render_section(etui@buffer:buffer(), list(etui@span:line()), integer(), integer(), integer(), status_bar()) -> etui@buffer:buffer().
render_section(Buf, Lines, X, Y, Max_w, Sb) ->
    case Lines of
        [] ->
            Buf;

        [Line | _] ->
            etui@span:render_line(Buf, {position, X, Y}, inherit_bar_style(Line, Sb), Max_w)
    end.

-file("src/etui/widgets/statusbar.gleam", 152).
-spec section_width(list(etui@span:line())) -> integer().
section_width(Lines) ->
    case Lines of
        [] ->
            0;

        [Line | _] ->
            etui@span:line_width(Line)
    end.

-file("src/etui/widgets/statusbar.gleam", 86).
-spec render(etui@buffer:buffer(), etui@geometry:rect(), status_bar()) -> etui@buffer:buffer().
-doc(~" Render status bar into the first row of `area`.
 Only one row is used; remaining rows in `area` are untouched.").
render(Buf, Area, Sb) ->
    case (erlang:element(2, erlang:element(3, Area)) =< 0) orelse (erlang:element(3, erlang:element(3, Area)) =< 0) of
        true ->
            Buf;

        false ->
            Y = erlang:element(3, erlang:element(2, Area)),
            W = erlang:element(2, erlang:element(3, Area)),
            Bg_row = etui@text:pad_right(~"", W),
            Buf1 = etui@buffer:set_string(Buf, {position, erlang:element(2, erlang:element(2, Area)), Y}, Bg_row, etui@style:new(erlang:element(5, Sb), erlang:element(6, Sb), etui@style:none())),
            Right_width = gleam@int:min(section_width(erlang:element(4, Sb)), W),
            Left_width = gleam@int:min(section_width(erlang:element(2, Sb)), gleam@int:max(0, W - Right_width)),
            Right_x = (erlang:element(2, erlang:element(2, Area)) + W) - Right_width,
            Buf2 = render_section(Buf1, erlang:element(2, Sb), erlang:element(2, erlang:element(2, Area)), Y, Left_width, Sb),
            Buf3 = render_section(Buf2, erlang:element(4, Sb), Right_x, Y, Right_width, Sb),
            Gap_start = erlang:element(2, erlang:element(2, Area)) + Left_width,
            Gap = gleam@int:max(0, Right_x - Gap_start),
            Center_width = gleam@int:min(section_width(erlang:element(3, Sb)), Gap),
            Center_x = Gap_start + ((Gap - Center_width) div 2),
            render_section(Buf3, erlang:element(3, Sb), Center_x, Y, Center_width, Sb)
    end.

