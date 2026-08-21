-module(etui@widgets@marquee).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([marquee_new/1, with_speed/2, with_separator/2, with_fg/2, with_style/4, render/4]).
-export_type([marquee/0]).

-type marquee() :: {marquee, binary(), integer(), binary(), etui@style:color(), etui@style:color(), etui@style:modifier()}.

-file("src/etui/widgets/marquee.gleam", 30).
-spec marquee_new(binary()) -> marquee().
marquee_new(Text) ->
    {marquee, Text, 8, ~"  ·  ", default, default, etui@style:none()}.

-file("src/etui/widgets/marquee.gleam", 41).
-spec with_speed(marquee(), integer()) -> marquee().
with_speed(M, Speed) ->
    {marquee, erlang:element(2, M), gleam@int:max(1, Speed), erlang:element(4, M), erlang:element(5, M), erlang:element(6, M), erlang:element(7, M)}.

-file("src/etui/widgets/marquee.gleam", 45).
-spec with_separator(marquee(), binary()) -> marquee().
with_separator(M, Sep) ->
    {marquee, erlang:element(2, M), erlang:element(3, M), Sep, erlang:element(5, M), erlang:element(6, M), erlang:element(7, M)}.

-file("src/etui/widgets/marquee.gleam", 49).
-spec with_fg(marquee(), etui@style:color()) -> marquee().
with_fg(M, Fg) ->
    {marquee, erlang:element(2, M), erlang:element(3, M), erlang:element(4, M), Fg, erlang:element(6, M), erlang:element(7, M)}.

-file("src/etui/widgets/marquee.gleam", 53).
-spec with_style(marquee(), etui@style:color(), etui@style:color(), etui@style:modifier()) -> marquee().
with_style(M, Fg, Bg, Modifier) ->
    {marquee, erlang:element(2, M), erlang:element(3, M), erlang:element(4, M), Fg, Bg, Modifier}.

-file("src/etui/widgets/marquee.gleam", 66).
-spec render(etui@buffer:buffer(), etui@geometry:rect(), marquee(), integer()) -> etui@buffer:buffer().
-doc(~" Render the scrolling marquee. `frame` drives scroll position.").
render(Buf, Area, M, Frame) ->
    case (erlang:element(2, erlang:element(3, Area)) =< 0) orelse (erlang:element(3, erlang:element(3, Area)) =< 0) of
        true ->
            Buf;

        false ->
            Unit = <<(erlang:element(2, M))/binary, (erlang:element(4, M))/binary>>,
            Unit_cells = etui@text:cell_width(Unit),
            case Unit_cells =< 0 of
                true ->
                    Buf;

                false ->
                    Speed = gleam@int:max(1, erlang:element(3, M)),
                    Offset_cells = case Unit_cells of
                        0 ->
                            0;

                        _value ->
                            case Speed of
                                0 ->
                                    0;

                                _value@1 ->
                                    Frame div _value@1
                            end rem _value
                    end,
                    Doubled = <<Unit/binary, Unit/binary>>,
                    Skip_graphemes = string:length(etui@text:truncate(Doubled, Offset_cells, ~"")),
                    Available = gleam@string:drop_start(Doubled, Skip_graphemes),
                    Padded = etui@text:pad_right(Available, erlang:element(2, erlang:element(3, Area))),
                    Line = etui@text:truncate(Padded, erlang:element(2, erlang:element(3, Area)), ~""),
                    etui@buffer:set_string(Buf, {position, erlang:element(2, erlang:element(2, Area)), erlang:element(3, erlang:element(2, Area))}, Line, etui@style:new(erlang:element(5, M), erlang:element(6, M), erlang:element(7, M)))
            end
    end.

