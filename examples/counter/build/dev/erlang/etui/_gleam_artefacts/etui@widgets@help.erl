-module(etui@widgets@help).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([binding/2, help_new/1, with_mode/2, toggle_mode/1, with_separator/2, with_key_color/2, with_description_color/2, with_bg/2, render/3]).
-export_type([binding/0, help_mode/0, help/0]).

-type binding() :: {binding, list(binary()), binary()}.

-type help_mode() :: short | full.

-type help() :: {help, list(binding()), help_mode(), binary(), etui@style:color(), etui@style:color(), etui@style:color()}.

-file("src/etui/widgets/help.gleam", 40).
-spec binding(list(binary()), binary()) -> binding().
binding(Keys, Description) ->
    {binding, Keys, Description}.

-file("src/etui/widgets/help.gleam", 44).
-spec help_new(list(binding())) -> help().
help_new(Bindings) ->
    {help, Bindings, short, ~" • ", default, {indexed, 8}, default}.

-file("src/etui/widgets/help.gleam", 55).
-spec with_mode(help(), help_mode()) -> help().
with_mode(H, Mode) ->
    {help, erlang:element(2, H), Mode, erlang:element(4, H), erlang:element(5, H), erlang:element(6, H), erlang:element(7, H)}.

-file("src/etui/widgets/help.gleam", 59).
-spec toggle_mode(help()) -> help().
toggle_mode(H) ->
    case erlang:element(3, H) of
        short ->
            {help, erlang:element(2, H), full, erlang:element(4, H), erlang:element(5, H), erlang:element(6, H), erlang:element(7, H)};

        full ->
            {help, erlang:element(2, H), short, erlang:element(4, H), erlang:element(5, H), erlang:element(6, H), erlang:element(7, H)}
    end.

-file("src/etui/widgets/help.gleam", 66).
-spec with_separator(help(), binary()) -> help().
with_separator(H, Sep) ->
    {help, erlang:element(2, H), erlang:element(3, H), Sep, erlang:element(5, H), erlang:element(6, H), erlang:element(7, H)}.

-file("src/etui/widgets/help.gleam", 70).
-spec with_key_color(help(), etui@style:color()) -> help().
with_key_color(H, Fg) ->
    {help, erlang:element(2, H), erlang:element(3, H), erlang:element(4, H), Fg, erlang:element(6, H), erlang:element(7, H)}.

-file("src/etui/widgets/help.gleam", 74).
-spec with_description_color(help(), etui@style:color()) -> help().
with_description_color(H, Fg) ->
    {help, erlang:element(2, H), erlang:element(3, H), erlang:element(4, H), erlang:element(5, H), Fg, erlang:element(7, H)}.

-file("src/etui/widgets/help.gleam", 78).
-spec with_bg(help(), etui@style:color()) -> help().
with_bg(H, Bg) ->
    {help, erlang:element(2, H), erlang:element(3, H), erlang:element(4, H), erlang:element(5, H), erlang:element(6, H), Bg}.

-file("src/etui/widgets/help.gleam", 133).
-spec render_full_rows(etui@buffer:buffer(), etui@geometry:rect(), help(), list(binding()), integer(), integer(), integer()) -> etui@buffer:buffer().
render_full_rows(Buf, Area, H, Bindings, Row, Key_col, Desc_col) ->
    case Row >= erlang:element(3, erlang:element(3, Area)) of
        true ->
            Buf;

        false ->
            case Bindings of
                [] ->
                    Buf;

                [B | Rest] ->
                    Y = erlang:element(3, erlang:element(2, Area)) + Row,
                    Key_text = etui@text:truncate(gleam@string:join(erlang:element(2, B), ~"/"), Key_col, ~""),
                    Key_padded = etui@text:pad_right(Key_text, Key_col),
                    Buf2 = etui@buffer:set_string(Buf, {position, erlang:element(2, erlang:element(2, Area)), Y}, Key_padded, etui@style:new(erlang:element(5, H), erlang:element(7, H), etui@style:bold())),
                    Desc_text = etui@text:truncate(erlang:element(3, B), Desc_col, ~""),
                    Desc_padded = etui@text:pad_right(Desc_text, Desc_col),
                    Buf3 = etui@buffer:set_string(Buf2, {position, (erlang:element(2, erlang:element(2, Area)) + Key_col) + 1, Y}, Desc_padded, etui@style:new(erlang:element(6, H), erlang:element(7, H), etui@style:none())),
                    render_full_rows(Buf3, Area, H, Rest, Row + 1, Key_col, Desc_col)
            end
    end.

-file("src/etui/widgets/help.gleam", 119).
-spec render_full(etui@buffer:buffer(), etui@geometry:rect(), help()) -> etui@buffer:buffer().
render_full(Buf, Area, H) ->
    Max_key_w = gleam@list:fold(erlang:element(2, H), 0, fun(Acc, B) ->
        gleam@int:max(Acc, etui@text:cell_width(gleam@string:join(erlang:element(2, B), ~"/")))
    end),
    Key_col = gleam@int:min(Max_key_w, gleam@int:max(0, erlang:element(2, erlang:element(3, Area)) div 3)),
    Desc_col = gleam@int:max(0, (erlang:element(2, erlang:element(3, Area)) - Key_col) - 1),
    render_full_rows(Buf, Area, H, erlang:element(2, H), 0, Key_col, Desc_col).

-file("src/etui/widgets/help.gleam", 100).
-spec render_short(etui@buffer:buffer(), etui@geometry:rect(), help()) -> etui@buffer:buffer().
render_short(Buf, Area, H) ->
    Txt = begin
        _pipe = erlang:element(2, H),
        _pipe@1 = gleam@list:map(_pipe, fun(B) ->
            <<<<(gleam@string:join(erlang:element(2, B), ~"/"))/binary, " "/utf8>>/binary, (erlang:element(3, B))/binary>>
        end),
        gleam@string:join(_pipe@1, erlang:element(4, H))
    end,
    Line = etui@text:truncate(Txt, erlang:element(2, erlang:element(3, Area)), ~""),
    Padded = etui@text:pad_right(Line, erlang:element(2, erlang:element(3, Area))),
    etui@buffer:set_string(Buf, erlang:element(2, Area), Padded, etui@style:new(erlang:element(6, H), erlang:element(7, H), etui@style:none())).

-file("src/etui/widgets/help.gleam", 85).
-spec render(etui@buffer:buffer(), etui@geometry:rect(), help()) -> etui@buffer:buffer().
render(Buf, Area, H) ->
    case (erlang:element(2, erlang:element(3, Area)) =< 0) orelse (erlang:element(3, erlang:element(3, Area)) =< 0) of
        true ->
            Buf;

        false ->
            case erlang:element(3, H) of
                short ->
                    render_short(Buf, Area, H);

                full ->
                    render_full(Buf, Area, H)
            end
    end.

