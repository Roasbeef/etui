-module(etui@widgets@dialog).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([dialog_new/1, state_new/0, with_labels/3, with_size/3, with_colors/3, with_style/2, with_focused_style/2, with_border/2, toggle/1, focus_confirm/1, focus_cancel/1, cancel/1, is_confirmed/1, render/4]).
-export_type([dialog/0, dialog_button/0, dialog_state/0]).

-type dialog() :: {dialog, binary(), binary(), binary(), integer(), integer(), etui@style:color(), etui@style:color(), etui@style:style(), etui@style:style(), etui@style:style(), etui@widgets@block:border()}.

-type dialog_button() :: confirm | cancel.

-type dialog_state() :: {dialog_state, dialog_button()}.

-file("src/etui/widgets/dialog.gleam", 68).
-spec dialog_new(binary()) -> dialog().
-doc(~" Dialog with default labels (\"OK\" / \"Cancel\") and a rounded border.").
dialog_new(Message) ->
    {dialog, Message, ~" OK ", ~" Cancel ", 0, 0, default, default, etui@style:new(default, default, etui@style:none()), etui@style:new(default, default, etui@style:none()), etui@style:new(default, default, etui@style:reverse()), rounded}.

-file("src/etui/widgets/dialog.gleam", 84).
-spec state_new() -> dialog_state().
state_new() ->
    {dialog_state, confirm}.

-file("src/etui/widgets/dialog.gleam", 91).
-spec with_labels(dialog(), binary(), binary()) -> dialog().
with_labels(D, Confirm, Cancel) ->
    {dialog, erlang:element(2, D), Confirm, Cancel, erlang:element(5, D), erlang:element(6, D), erlang:element(7, D), erlang:element(8, D), erlang:element(9, D), erlang:element(10, D), erlang:element(11, D), erlang:element(12, D)}.

-file("src/etui/widgets/dialog.gleam", 95).
-spec with_size(dialog(), integer(), integer()) -> dialog().
with_size(D, Width, Height) ->
    {dialog, erlang:element(2, D), erlang:element(3, D), erlang:element(4, D), Width, Height, erlang:element(7, D), erlang:element(8, D), erlang:element(9, D), erlang:element(10, D), erlang:element(11, D), erlang:element(12, D)}.

-file("src/etui/widgets/dialog.gleam", 99).
-spec with_colors(dialog(), etui@style:color(), etui@style:color()) -> dialog().
with_colors(D, Fg, Bg) ->
    {dialog, erlang:element(2, D), erlang:element(3, D), erlang:element(4, D), erlang:element(5, D), erlang:element(6, D), Fg, Bg, erlang:element(9, D), erlang:element(10, D), erlang:element(11, D), erlang:element(12, D)}.

-file("src/etui/widgets/dialog.gleam", 103).
-spec with_style(dialog(), etui@style:style()) -> dialog().
with_style(D, S) ->
    {dialog, erlang:element(2, D), erlang:element(3, D), erlang:element(4, D), erlang:element(5, D), erlang:element(6, D), erlang:element(2, S), erlang:element(3, S), erlang:element(9, D), erlang:element(10, D), erlang:element(11, D), erlang:element(12, D)}.

-file("src/etui/widgets/dialog.gleam", 107).
-spec with_focused_style(dialog(), etui@style:style()) -> dialog().
with_focused_style(D, S) ->
    {dialog, erlang:element(2, D), erlang:element(3, D), erlang:element(4, D), erlang:element(5, D), erlang:element(6, D), erlang:element(7, D), erlang:element(8, D), erlang:element(9, D), erlang:element(10, D), S, erlang:element(12, D)}.

-file("src/etui/widgets/dialog.gleam", 111).
-spec with_border(dialog(), etui@widgets@block:border()) -> dialog().
with_border(D, B) ->
    {dialog, erlang:element(2, D), erlang:element(3, D), erlang:element(4, D), erlang:element(5, D), erlang:element(6, D), erlang:element(7, D), erlang:element(8, D), erlang:element(9, D), erlang:element(10, D), erlang:element(11, D), B}.

-file("src/etui/widgets/dialog.gleam", 119).
-spec toggle(dialog_state()) -> dialog_state().
-doc(~" Toggle focus between Confirm and Cancel.").
toggle(State) ->
    case erlang:element(2, State) of
        confirm ->
            {dialog_state, cancel};

        cancel ->
            {dialog_state, confirm}
    end.

-file("src/etui/widgets/dialog.gleam", 127).
-spec focus_confirm(dialog_state()) -> dialog_state().
-doc(~" Focus the Confirm button.").
focus_confirm(_) ->
    {dialog_state, confirm}.

-file("src/etui/widgets/dialog.gleam", 132).
-spec focus_cancel(dialog_state()) -> dialog_state().
-doc(~" Focus the Cancel button.").
focus_cancel(_) ->
    {dialog_state, cancel}.

-file("src/etui/widgets/dialog.gleam", 137).
-spec cancel(dialog_state()) -> dialog_state().
-doc(~" Convenience: focus Cancel (same as pressing Escape conceptually).").
cancel(_) ->
    {dialog_state, cancel}.

-file("src/etui/widgets/dialog.gleam", 142).
-spec is_confirmed(dialog_state()) -> boolean().
-doc(~" `True` if the Confirm button is focused.").
is_confirmed(State) ->
    erlang:element(2, State) =:= confirm.

-file("src/etui/widgets/dialog.gleam", 221).
-spec render_buttons(etui@buffer:buffer(), etui@geometry:rect(), dialog(), dialog_state(), integer()) -> etui@buffer:buffer().
render_buttons(Buf, Inner, D, State, Btn_y) ->
    Conf_w = etui@text:cell_width(erlang:element(3, D)),
    Canc_w = etui@text:cell_width(erlang:element(4, D)),
    Total_btn_w = (Conf_w + 1) + Canc_w,
    Btn_x = erlang:element(2, erlang:element(2, Inner)) + ((erlang:element(2, erlang:element(3, Inner)) - Total_btn_w) div 2),
    {Conf_st, Canc_st} = case erlang:element(2, State) of
        confirm ->
            {erlang:element(11, D), erlang:element(10, D)};

        cancel ->
            {erlang:element(9, D), erlang:element(11, D)}
    end,
    Buf1 = etui@buffer:set_string(Buf, {position, Btn_x, Btn_y}, erlang:element(3, D), Conf_st),
    Buf2 = etui@buffer:set_string(Buf1, {position, (Btn_x + Conf_w) + 1, Btn_y}, erlang:element(4, D), Canc_st),
    Buf2.

-file("src/etui/widgets/dialog.gleam", 150).
-spec render(etui@buffer:buffer(), etui@geometry:rect(), dialog(), dialog_state()) -> etui@buffer:buffer().
-doc(~" Render the dialog centered within `area`.").
render(Buf, Area, D, State) ->
    Msg_w = etui@text:cell_width(erlang:element(2, D)),
    Btn_w = (etui@text:cell_width(erlang:element(3, D)) + etui@text:cell_width(erlang:element(4, D))) + 3,
    Content_w = case Msg_w > Btn_w of
        true ->
            Msg_w;

        false ->
            Btn_w
    end,
    Box_w = case erlang:element(5, D) > 0 of
        true ->
            erlang:element(5, D);

        false ->
            Content_w + 4
    end,
    Box_h = case erlang:element(6, D) > 0 of
        true ->
            erlang:element(6, D);

        false ->
            6
    end,
    Box_w@1 = case Box_w < 20 of
        true ->
            20;

        false ->
            Box_w
    end,
    Box_w@2 = case Box_w@1 > erlang:element(2, erlang:element(3, Area)) of
        true ->
            erlang:element(2, erlang:element(3, Area));

        false ->
            Box_w@1
    end,
    Box_h@1 = case Box_h > erlang:element(3, erlang:element(3, Area)) of
        true ->
            erlang:element(3, erlang:element(3, Area));

        false ->
            Box_h
    end,
    X = erlang:element(2, erlang:element(2, Area)) + ((erlang:element(2, erlang:element(3, Area)) - Box_w@2) div 2),
    Y = erlang:element(3, erlang:element(2, Area)) + ((erlang:element(3, erlang:element(3, Area)) - Box_h@1) div 2),
    Box_area = {rect, {position, X, Y}, {size, Box_w@2, Box_h@1}},
    Blk = begin
        _pipe = etui@widgets@block:block_new(),
        _pipe@1 = etui@widgets@block:with_border(_pipe, erlang:element(12, D)),
        _pipe@2 = etui@widgets@block:with_style(_pipe@1, erlang:element(7, D), erlang:element(8, D)),
        etui@widgets@block:with_bg_fill(_pipe@2)
    end,
    Buf1 = etui@widgets@block:render(Buf, Box_area, Blk),
    Inner = etui@widgets@block:inner(Box_area, Blk),
    Msg_x = erlang:element(2, erlang:element(2, Inner)) + ((erlang:element(2, erlang:element(3, Inner)) - etui@text:cell_width(erlang:element(2, D))) div 2),
    Msg_y = erlang:element(3, erlang:element(2, Inner)) + ((erlang:element(3, erlang:element(3, Inner)) - 3) div 2),
    Buf2 = case (Msg_y >= erlang:element(3, erlang:element(2, Inner))) andalso (erlang:element(3, erlang:element(3, Inner)) > 0) of
        false ->
            Buf1;

        true ->
            etui@buffer:set_string(Buf1, {position, Msg_x, Msg_y}, etui@text:truncate(erlang:element(2, D), erlang:element(2, erlang:element(3, Inner)), ~"…"), etui@style:new(erlang:element(7, D), erlang:element(8, D), etui@style:none()))
    end,
    Btn_y = (erlang:element(3, erlang:element(2, Inner)) + erlang:element(3, erlang:element(3, Inner))) - 1,
    case (Btn_y >= erlang:element(3, erlang:element(2, Inner))) andalso (erlang:element(3, erlang:element(3, Inner)) >= 3) of
        false ->
            Buf2;

        true ->
            render_buttons(Buf2, Inner, D, State, Btn_y)
    end.

