-module(etui@widgets@input).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([input_new/1, with_prompt/2, with_password/2, with_mask/2, with_validator/2, with_error_color/2, validate/2, with_max_length/2, with_colors/3, with_style/2, state_new/0, state_from_string/1, insert_char/3, backspace/1, move_cursor_left/1, move_cursor_right/1, move_to_start/1, move_to_end/1, delete_to_end/1, clear_state/1, render/4]).
-export_type([input_widget/0, input_state/0]).

-type input_widget() :: {input_widget, integer(), binary(), etui@style:color(), etui@style:color(), fun((binary()) -> {ok, nil} | {error, binary()}), etui@style:color(), binary(), boolean(), binary()}.

-type input_state() :: {input_state, binary(), integer()}.

-file("src/etui/widgets/input.gleam", 54).
-spec input_new(binary()) -> input_widget().
-doc(~" New input widget with placeholder text. Default max length: 256 cells.").
input_new(Placeholder) ->
    {input_widget, 256, Placeholder, default, default, fun(_) ->
        {ok, nil}
    end, {indexed, 1}, ~"", false, ~"*"}.

-file("src/etui/widgets/input.gleam", 69).
-spec with_prompt(input_widget(), binary()) -> input_widget().
-doc(~" Set a prefix shown before the value (e.g. `\"> \"`).").
with_prompt(I, Prompt) ->
    {input_widget, erlang:element(2, I), erlang:element(3, I), erlang:element(4, I), erlang:element(5, I), erlang:element(6, I), erlang:element(7, I), Prompt, erlang:element(9, I), erlang:element(10, I)}.

-file("src/etui/widgets/input.gleam", 74).
-spec with_password(input_widget(), boolean()) -> input_widget().
-doc(~" Render each value cell as the mask character. Use for password fields.").
with_password(I, Password) ->
    {input_widget, erlang:element(2, I), erlang:element(3, I), erlang:element(4, I), erlang:element(5, I), erlang:element(6, I), erlang:element(7, I), erlang:element(8, I), Password, erlang:element(10, I)}.

-file("src/etui/widgets/input.gleam", 79).
-spec with_mask(input_widget(), binary()) -> input_widget().
-doc(~" Mask character used when `password` is True. Default `\"*\"`.").
with_mask(I, Mask) ->
    {input_widget, erlang:element(2, I), erlang:element(3, I), erlang:element(4, I), erlang:element(5, I), erlang:element(6, I), erlang:element(7, I), erlang:element(8, I), erlang:element(9, I), Mask}.

-file("src/etui/widgets/input.gleam", 84).
-spec with_validator(input_widget(), fun((binary()) -> {ok, nil} | {error, binary()})) -> input_widget().
-doc(~" Set a validation function. Call `validate/2` to run it.").
with_validator(I, V) ->
    {input_widget, erlang:element(2, I), erlang:element(3, I), erlang:element(4, I), erlang:element(5, I), V, erlang:element(7, I), erlang:element(8, I), erlang:element(9, I), erlang:element(10, I)}.

-file("src/etui/widgets/input.gleam", 89).
-spec with_error_color(input_widget(), etui@style:color()) -> input_widget().
-doc(~" Set the color used to display validation errors.").
with_error_color(I, Fg) ->
    {input_widget, erlang:element(2, I), erlang:element(3, I), erlang:element(4, I), erlang:element(5, I), erlang:element(6, I), Fg, erlang:element(8, I), erlang:element(9, I), erlang:element(10, I)}.

-file("src/etui/widgets/input.gleam", 94).
-spec validate(input_widget(), binary()) -> {ok, nil} | {error, binary()}.
-doc(~" Run the validator on `value`. Returns Ok(Nil) or Error(message).").
validate(I, Value) ->
    (erlang:element(6, I))(Value).

-file("src/etui/widgets/input.gleam", 99).
-spec with_max_length(input_widget(), integer()) -> input_widget().
-doc(~" Maximum value width in cells (wide characters count as 2).").
with_max_length(I, Len) ->
    {input_widget, Len, erlang:element(3, I), erlang:element(4, I), erlang:element(5, I), erlang:element(6, I), erlang:element(7, I), erlang:element(8, I), erlang:element(9, I), erlang:element(10, I)}.

-file("src/etui/widgets/input.gleam", 103).
-spec with_colors(input_widget(), etui@style:color(), etui@style:color()) -> input_widget().
with_colors(I, Fg, Bg) ->
    {input_widget, erlang:element(2, I), erlang:element(3, I), Fg, Bg, erlang:element(6, I), erlang:element(7, I), erlang:element(8, I), erlang:element(9, I), erlang:element(10, I)}.

-file("src/etui/widgets/input.gleam", 111).
-spec with_style(input_widget(), etui@style:style()) -> input_widget().
with_style(I, S) ->
    {input_widget, erlang:element(2, I), erlang:element(3, I), erlang:element(2, S), erlang:element(3, S), erlang:element(6, I), erlang:element(7, I), erlang:element(8, I), erlang:element(9, I), erlang:element(10, I)}.

-file("src/etui/widgets/input.gleam", 119).
-spec state_new() -> input_state().
-doc(~" Initial state: empty value, cursor at 0.").
state_new() ->
    {input_state, ~"", 0}.

-file("src/etui/widgets/input.gleam", 124).
-spec state_from_string(binary()) -> input_state().
-doc(~" State pre-populated with a string; cursor placed at the end.").
state_from_string(S) ->
    {input_state, S, etui@text:cell_width(S)}.

-file("src/etui/widgets/input.gleam", 132).
-spec insert_char(input_widget(), input_state(), binary()) -> input_state().
-doc(~" Insert character at cursor. Respects widget max_length.").
insert_char(Widget, State, Ch) ->
    case etui@text:cell_width(erlang:element(2, State)) >= erlang:element(2, Widget) of
        true ->
            State;

        false ->
            Before = etui@text:truncate(erlang:element(2, State), erlang:element(3, State), ~""),
            After = gleam@string:drop_start(erlang:element(2, State), string:length(Before)),
            {input_state, <<<<Before/binary, Ch/binary>>/binary, After/binary>>, erlang:element(3, State) + etui@text:cell_width(Ch)}
    end.

-file("src/etui/widgets/input.gleam", 151).
-spec backspace(input_state()) -> input_state().
-doc(~" Delete the character immediately before the cursor (backspace semantics).").
backspace(State) ->
    case erlang:element(3, State) =< 0 of
        true ->
            State;

        false ->
            Before = etui@text:truncate(erlang:element(2, State), erlang:element(3, State) - 1, ~""),
            Graphemes_at_cursor = string:length(etui@text:truncate(erlang:element(2, State), erlang:element(3, State), ~"")),
            After = gleam@string:drop_start(erlang:element(2, State), Graphemes_at_cursor),
            {input_state, <<Before/binary, After/binary>>, etui@text:cell_width(Before)}
    end.

-file("src/etui/widgets/input.gleam", 165).
-spec move_cursor_left(input_state()) -> input_state().
-doc(~" Move cursor one cell left, clamped to 0.").
move_cursor_left(State) ->
    case erlang:element(3, State) =< 0 of
        true ->
            State;

        false ->
            New_cursor = etui@text:cell_width(etui@text:truncate(erlang:element(2, State), erlang:element(3, State) - 1, ~"")),
            {input_state, erlang:element(2, State), New_cursor}
    end.

-file("src/etui/widgets/input.gleam", 259).
-spec grapheme_width_at(binary(), integer()) -> integer().
grapheme_width_at(S, Cell_pos) ->
    Prefix = etui@text:truncate(S, Cell_pos, ~""),
    Rest = gleam@string:drop_start(S, string:length(Prefix)),
    case gleam@string:to_graphemes(Rest) of
        [G | _] ->
            etui@text:cell_width(G);

        [] ->
            1
    end.

-file("src/etui/widgets/input.gleam", 177).
-spec move_cursor_right(input_state()) -> input_state().
-doc(~" Move cursor one cell right, clamped to end of value.").
move_cursor_right(State) ->
    case erlang:element(3, State) >= etui@text:cell_width(erlang:element(2, State)) of
        true ->
            State;

        false ->
            Step = grapheme_width_at(erlang:element(2, State), erlang:element(3, State)),
            {input_state, erlang:element(2, State), erlang:element(3, State) + Step}
    end.

-file("src/etui/widgets/input.gleam", 188).
-spec move_to_start(input_state()) -> input_state().
-doc(~" Move cursor to beginning of value.").
move_to_start(State) ->
    {input_state, erlang:element(2, State), 0}.

-file("src/etui/widgets/input.gleam", 193).
-spec move_to_end(input_state()) -> input_state().
-doc(~" Move cursor to end of value.").
move_to_end(State) ->
    {input_state, erlang:element(2, State), etui@text:cell_width(erlang:element(2, State))}.

-file("src/etui/widgets/input.gleam", 198).
-spec delete_to_end(input_state()) -> input_state().
-doc(~" Delete from cursor to end of value.").
delete_to_end(State) ->
    Before = etui@text:truncate(erlang:element(2, State), erlang:element(3, State), ~""),
    {input_state, Before, erlang:element(3, State)}.

-file("src/etui/widgets/input.gleam", 204).
-spec clear_state(input_state()) -> input_state().
-doc(~" Reset value and cursor to empty.").
clear_state(_) ->
    {input_state, ~"", 0}.

-file("src/etui/widgets/input.gleam", 214).
-spec render(etui@buffer:buffer(), etui@geometry:rect(), input_widget(), input_state()) -> etui@buffer:buffer().
-doc(~" Render the input field. Shows `state.value` (bold) or placeholder when empty.
 Text is truncated to fit `area.size.width` (minus one cell reserved for the
 trailing cursor). When `password` is True the value is masked.").
render(Buf, Area, Widget, State) ->
    case erlang:element(2, erlang:element(3, Area)) =< 0 of
        true ->
            Buf;

        false ->
            Has_value = erlang:element(2, State) /= ~"",
            Value_display = case erlang:element(9, Widget) andalso Has_value of
                true ->
                    gleam@string:repeat(erlang:element(10, Widget), etui@text:cell_width(erlang:element(2, State)));

                false ->
                    erlang:element(2, State)
            end,
            Display_text = case Has_value of
                true ->
                    <<(erlang:element(8, Widget))/binary, Value_display/binary>>;

                false ->
                    <<(erlang:element(8, Widget))/binary, (erlang:element(3, Widget))/binary>>
            end,
            C = etui@text:cell_width(erlang:element(8, Widget)) + erlang:element(3, State),
            W_avail = gleam@int:max(1, erlang:element(2, erlang:element(3, Area))),
            View_start = case C >= W_avail of
                true ->
                    (C - W_avail) + 1;

                false ->
                    0
            end,
            Prefix = etui@text:truncate(Display_text, View_start, ~""),
            Suffix = gleam@string:drop_start(Display_text, string:length(Prefix)),
            Truncated = etui@text:truncate(Suffix, W_avail, ~""),
            Padded = etui@text:pad_right(Truncated, W_avail),
            Modifier = case Has_value of
                true ->
                    etui@style:bold();

                false ->
                    etui@style:none()
            end,
            etui@buffer:set_string(Buf, erlang:element(2, Area), Padded, etui@style:new(erlang:element(4, Widget), erlang:element(5, Widget), Modifier))
    end.

