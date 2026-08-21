-module(etui@widgets@fieldset).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([fieldset_new/1, with_align/2, with_line_char/2, with_pad/2, with_colors/3, with_title_color/2, render/3]).
-export_type([fieldset_align/0, fieldset/0]).

-type fieldset_align() :: align_left | align_center | align_right.

-type fieldset() :: {fieldset, binary(), fieldset_align(), binary(), integer(), etui@style:color(), etui@style:color(), etui@style:color()}.

-file("src/etui/widgets/fieldset.gleam", 36).
-spec fieldset_new(binary()) -> fieldset().
fieldset_new(Title) ->
    {fieldset, Title, align_left, ~"─", 2, default, default, default}.

-file("src/etui/widgets/fieldset.gleam", 48).
-spec with_align(fieldset(), fieldset_align()) -> fieldset().
with_align(Fs, A) ->
    {fieldset, erlang:element(2, Fs), A, erlang:element(4, Fs), erlang:element(5, Fs), erlang:element(6, Fs), erlang:element(7, Fs), erlang:element(8, Fs)}.

-file("src/etui/widgets/fieldset.gleam", 52).
-spec with_line_char(fieldset(), binary()) -> fieldset().
with_line_char(Fs, C) ->
    {fieldset, erlang:element(2, Fs), erlang:element(3, Fs), C, erlang:element(5, Fs), erlang:element(6, Fs), erlang:element(7, Fs), erlang:element(8, Fs)}.

-file("src/etui/widgets/fieldset.gleam", 56).
-spec with_pad(fieldset(), integer()) -> fieldset().
with_pad(Fs, P) ->
    {fieldset, erlang:element(2, Fs), erlang:element(3, Fs), erlang:element(4, Fs), gleam@int:max(0, P), erlang:element(6, Fs), erlang:element(7, Fs), erlang:element(8, Fs)}.

-file("src/etui/widgets/fieldset.gleam", 60).
-spec with_colors(fieldset(), etui@style:color(), etui@style:color()) -> fieldset().
with_colors(Fs, Fg, Bg) ->
    {fieldset, erlang:element(2, Fs), erlang:element(3, Fs), erlang:element(4, Fs), erlang:element(5, Fs), Fg, Bg, erlang:element(8, Fs)}.

-file("src/etui/widgets/fieldset.gleam", 64).
-spec with_title_color(fieldset(), etui@style:color()) -> fieldset().
with_title_color(Fs, Fg) ->
    {fieldset, erlang:element(2, Fs), erlang:element(3, Fs), erlang:element(4, Fs), erlang:element(5, Fs), erlang:element(6, Fs), erlang:element(7, Fs), Fg}.

-file("src/etui/widgets/fieldset.gleam", 71).
-spec render(etui@buffer:buffer(), etui@geometry:rect(), fieldset()) -> etui@buffer:buffer().
render(Buf, Area, Fs) ->
    case (erlang:element(2, erlang:element(3, Area)) =< 0) orelse (erlang:element(3, erlang:element(3, Area)) =< 0) of
        true ->
            Buf;

        false ->
            W = erlang:element(2, erlang:element(3, Area)),
            Title_w = etui@text:cell_width(erlang:element(2, Fs)),
            case Title_w of
                0 ->
                    Line = gleam@string:repeat(erlang:element(4, Fs), W),
                    etui@buffer:set_string(Buf, erlang:element(2, Area), Line, etui@style:new(erlang:element(6, Fs), erlang:element(7, Fs), etui@style:none()));

                _ ->
                    Label_w = Title_w + 2,
                    Avail = gleam@int:max(0, W - Label_w),
                    {Left_n, Right_n} = case erlang:element(3, Fs) of
                        align_left ->
                            {erlang:element(5, Fs), gleam@int:max(0, Avail - erlang:element(5, Fs))};

                        align_right ->
                            {gleam@int:max(0, Avail - erlang:element(5, Fs)), erlang:element(5, Fs)};

                        align_center ->
                            Half = Avail div 2,
                            {Half, Avail - Half}
                    end,
                    Left = gleam@string:repeat(erlang:element(4, Fs), Left_n),
                    Right = gleam@string:repeat(erlang:element(4, Fs), Right_n),
                    Buf2 = etui@buffer:set_string(Buf, erlang:element(2, Area), Left, etui@style:new(erlang:element(6, Fs), erlang:element(7, Fs), etui@style:none())),
                    Buf3 = etui@buffer:set_string(Buf2, {position, erlang:element(2, erlang:element(2, Area)) + Left_n, erlang:element(3, erlang:element(2, Area))}, <<<<" "/utf8, (erlang:element(2, Fs))/binary>>/binary, " "/utf8>>, etui@style:new(erlang:element(8, Fs), erlang:element(7, Fs), etui@style:bold())),
                    etui@buffer:set_string(Buf3, {position, (erlang:element(2, erlang:element(2, Area)) + Left_n) + Label_w, erlang:element(3, erlang:element(2, Area))}, Right, etui@style:new(erlang:element(6, Fs), erlang:element(7, Fs), etui@style:none()))
            end
    end.

