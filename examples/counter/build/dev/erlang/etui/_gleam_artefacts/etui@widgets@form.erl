-module(etui@widgets@form).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([form_new/0, add_field/5, add_required/4, add_optional/4, with_field_max_length/2, with_label_width/2, with_colors/3, with_focused_colors/3, with_error_color/2, focus_next/1, focus_prev/1, focus_index/2, type_char/2, backspace/1, clear_focused/1, set_value/3, validate/1, is_valid/1, submit/1, is_submitted/1, reset/1, get_value/2, values/1, render/3]).
-export_type([field/1, form/1]).

-type field(GEM) :: {field, GEM, binary(), binary(), fun((binary()) -> {ok, nil} | {error, binary()}), binary(), integer()}.

-type form(GEN) :: {form, list(field(GEN)), integer(), boolean(), integer(), etui@style:color(), etui@style:color(), etui@style:color(), etui@style:color(), etui@style:color()}.

-file("src/etui/widgets/form.gleam", 80).
-spec form_new() -> form(any()).
-doc(~" Empty form with default styles.").
form_new() ->
    {form, [], 0, false, 0, default, default, default, {indexed, 4}, {indexed, 1}}.

-file("src/etui/widgets/form.gleam", 95).
-spec add_field(form(GES), GES, binary(), binary(), fun((binary()) -> {ok, nil} | {error, binary()})) -> form(GES).
-doc(~" Append a field with a validator.").
add_field(F, Id, Label, Default_value, Validator) ->
    Field = {field, Id, Label, Default_value, Validator, ~"", 0},
    {form, lists:append(erlang:element(2, F), [Field]), erlang:element(3, F), erlang:element(4, F), erlang:element(5, F), erlang:element(6, F), erlang:element(7, F), erlang:element(8, F), erlang:element(9, F), erlang:element(10, F)}.

-file("src/etui/widgets/form.gleam", 115).
-spec add_required(form(GEV), GEV, binary(), binary()) -> form(GEV).
-doc(~" Append a required text field (non-empty validator).").
add_required(F, Id, Label, Default_value) ->
    add_field(F, Id, Label, Default_value, fun(V) ->
        case V of
            ~"" ->
                {error, ~"required"};

            _ ->
                {ok, nil}
        end
    end).

-file("src/etui/widgets/form.gleam", 130).
-spec add_optional(form(GEY), GEY, binary(), binary()) -> form(GEY).
-doc(~" Append an optional field (always valid).").
add_optional(F, Id, Label, Default_value) ->
    add_field(F, Id, Label, Default_value, fun(_) ->
        {ok, nil}
    end).

-file("src/etui/widgets/form.gleam", 140).
-spec with_field_max_length(form(GFB), integer()) -> form(GFB).
-doc(~" Set max grapheme length for the most-recently added field.").
with_field_max_length(F, Max) ->
    Fields = gleam@list:index_map(erlang:element(2, F), fun(Field, I) ->
        case I =:= (erlang:length(erlang:element(2, F)) - 1) of
            true ->
                {field, erlang:element(2, Field), erlang:element(3, Field), erlang:element(4, Field), erlang:element(5, Field), erlang:element(6, Field), Max};

            false ->
                Field
        end
    end),
    {form, Fields, erlang:element(3, F), erlang:element(4, F), erlang:element(5, F), erlang:element(6, F), erlang:element(7, F), erlang:element(8, F), erlang:element(9, F), erlang:element(10, F)}.

-file("src/etui/widgets/form.gleam", 152).
-spec with_label_width(form(GFE), integer()) -> form(GFE).
-doc(~" Override label column width (auto-computed from labels if 0).").
with_label_width(F, W) ->
    {form, erlang:element(2, F), erlang:element(3, F), erlang:element(4, F), W, erlang:element(6, F), erlang:element(7, F), erlang:element(8, F), erlang:element(9, F), erlang:element(10, F)}.

-file("src/etui/widgets/form.gleam", 157).
-spec with_colors(form(GFH), etui@style:color(), etui@style:color()) -> form(GFH).
-doc(~" Set base foreground/background.").
with_colors(F, Fg, Bg) ->
    {form, erlang:element(2, F), erlang:element(3, F), erlang:element(4, F), erlang:element(5, F), Fg, Bg, erlang:element(8, F), erlang:element(9, F), erlang:element(10, F)}.

-file("src/etui/widgets/form.gleam", 162).
-spec with_focused_colors(form(GFK), etui@style:color(), etui@style:color()) -> form(GFK).
-doc(~" Set focused field highlight colors.").
with_focused_colors(F, Fg, Bg) ->
    {form, erlang:element(2, F), erlang:element(3, F), erlang:element(4, F), erlang:element(5, F), erlang:element(6, F), erlang:element(7, F), Fg, Bg, erlang:element(10, F)}.

-file("src/etui/widgets/form.gleam", 171).
-spec with_error_color(form(GFN), etui@style:color()) -> form(GFN).
-doc(~" Set validation error text color.").
with_error_color(F, Fg) ->
    {form, erlang:element(2, F), erlang:element(3, F), erlang:element(4, F), erlang:element(5, F), erlang:element(6, F), erlang:element(7, F), erlang:element(8, F), erlang:element(9, F), Fg}.

-file("src/etui/widgets/form.gleam", 179).
-spec focus_next(form(GFQ)) -> form(GFQ).
-doc(~" Move focus to the next field (wraps around).").
focus_next(F) ->
    N = erlang:length(erlang:element(2, F)),
    case N of
        0 ->
            F;

        _ ->
            {form, erlang:element(2, F), case N of
                0 ->
                    0;

                _value ->
                    (erlang:element(3, F) + 1) rem _value
            end, erlang:element(4, F), erlang:element(5, F), erlang:element(6, F), erlang:element(7, F), erlang:element(8, F), erlang:element(9, F), erlang:element(10, F)}
    end.

-file("src/etui/widgets/form.gleam", 188).
-spec focus_prev(form(GFT)) -> form(GFT).
-doc(~" Move focus to the previous field (wraps around).").
focus_prev(F) ->
    N = erlang:length(erlang:element(2, F)),
    case N of
        0 ->
            F;

        _ ->
            {form, erlang:element(2, F), begin
                Prev = erlang:element(3, F) - 1,
                case Prev < 0 of
                    true ->
                        N - 1;

                    false ->
                        Prev
                end
            end, erlang:element(4, F), erlang:element(5, F), erlang:element(6, F), erlang:element(7, F), erlang:element(8, F), erlang:element(9, F), erlang:element(10, F)}
    end.

-file("src/etui/widgets/form.gleam", 204).
-spec focus_index(form(GFW), integer()) -> form(GFW).
-doc(~" Move focus to a specific field by index.").
focus_index(F, Idx) ->
    N = erlang:length(erlang:element(2, F)),
    case (Idx >= 0) andalso (Idx < N) of
        true ->
            {form, erlang:element(2, F), Idx, erlang:element(4, F), erlang:element(5, F), erlang:element(6, F), erlang:element(7, F), erlang:element(8, F), erlang:element(9, F), erlang:element(10, F)};

        false ->
            F
    end.

-file("src/etui/widgets/form.gleam", 437).
-spec update_focused(form(GHM), fun((field(GHM)) -> field(GHM))) -> form(GHM).
update_focused(F, Updater) ->
    Fields = gleam@list:index_map(erlang:element(2, F), fun(Field, I) ->
        case I =:= erlang:element(3, F) of
            true ->
                Updater(Field);

            false ->
                Field
        end
    end),
    {form, Fields, erlang:element(3, F), erlang:element(4, F), erlang:element(5, F), erlang:element(6, F), erlang:element(7, F), erlang:element(8, F), erlang:element(9, F), erlang:element(10, F)}.

-file("src/etui/widgets/form.gleam", 216).
-spec type_char(form(GFZ), binary()) -> form(GFZ).
-doc(~" Type a character into the currently focused field.").
type_char(F, Ch) ->
    update_focused(F, fun(Field) ->
        case (erlang:element(7, Field) > 0) andalso (etui@text:cell_width(erlang:element(4, Field)) >= erlang:element(7, Field)) of
            true ->
                Field;

            false ->
                {field, erlang:element(2, Field), erlang:element(3, Field), <<(erlang:element(4, Field))/binary, Ch/binary>>, erlang:element(5, Field), ~"", erlang:element(7, Field)}
        end
    end).

-file("src/etui/widgets/form.gleam", 228).
-spec backspace(form(GGC)) -> form(GGC).
-doc(~" Backspace on the currently focused field.").
backspace(F) ->
    update_focused(F, fun(Field) ->
        case erlang:element(4, Field) of
            ~"" ->
                Field;

            V ->
                Graphemes = etui@text:graphemes(V),
                Dropped = gleam@list:take(Graphemes, erlang:length(Graphemes) - 1),
                {field, erlang:element(2, Field), erlang:element(3, Field), erlang:list_to_binary(Dropped), erlang:element(5, Field), ~"", erlang:element(7, Field)}
        end
    end).

-file("src/etui/widgets/form.gleam", 242).
-spec clear_focused(form(GGF)) -> form(GGF).
-doc(~" Clear the currently focused field's value.").
clear_focused(F) ->
    update_focused(F, fun(Field) ->
        {field, erlang:element(2, Field), erlang:element(3, Field), ~"", erlang:element(5, Field), ~"", erlang:element(7, Field)}
    end).

-file("src/etui/widgets/form.gleam", 247).
-spec set_value(form(GGI), GGI, binary()) -> form(GGI).
-doc(~" Set a field's value by id.").
set_value(F, Id, Value) ->
    Fields = gleam@list:map(erlang:element(2, F), fun(Field) ->
        case erlang:element(2, Field) =:= Id of
            true ->
                {field, erlang:element(2, Field), erlang:element(3, Field), Value, erlang:element(5, Field), ~"", erlang:element(7, Field)};

            false ->
                Field
        end
    end),
    {form, Fields, erlang:element(3, F), erlang:element(4, F), erlang:element(5, F), erlang:element(6, F), erlang:element(7, F), erlang:element(8, F), erlang:element(9, F), erlang:element(10, F)}.

-file("src/etui/widgets/form.gleam", 262).
-spec validate(form(GGL)) -> form(GGL).
-doc(~" Validate all fields. Returns form with error messages populated.").
validate(F) ->
    Fields = gleam@list:map(erlang:element(2, F), fun(Field) ->
        case (erlang:element(5, Field))(erlang:element(4, Field)) of
            {ok, _} ->
                {field, erlang:element(2, Field), erlang:element(3, Field), erlang:element(4, Field), erlang:element(5, Field), ~"", erlang:element(7, Field)};

            {error, Msg} ->
                {field, erlang:element(2, Field), erlang:element(3, Field), erlang:element(4, Field), erlang:element(5, Field), Msg, erlang:element(7, Field)}
        end
    end),
    {form, Fields, erlang:element(3, F), erlang:element(4, F), erlang:element(5, F), erlang:element(6, F), erlang:element(7, F), erlang:element(8, F), erlang:element(9, F), erlang:element(10, F)}.

-file("src/etui/widgets/form.gleam", 274).
-spec is_valid(form(any())) -> boolean().
-doc(~" True if all fields are valid (no errors after validation).").
is_valid(F) ->
    gleam@list:all(erlang:element(2, F), fun(Field) ->
        case (erlang:element(5, Field))(erlang:element(4, Field)) of
            {ok, _} ->
                true;

            {error, _} ->
                false
        end
    end).

-file("src/etui/widgets/form.gleam", 284).
-spec submit(form(GGQ)) -> form(GGQ).
-doc(~" Validate then mark as submitted if valid. Returns the form.").
submit(F) ->
    Validated = validate(F),
    case is_valid(Validated) of
        true ->
            {form, erlang:element(2, Validated), erlang:element(3, Validated), true, erlang:element(5, Validated), erlang:element(6, Validated), erlang:element(7, Validated), erlang:element(8, Validated), erlang:element(9, Validated), erlang:element(10, Validated)};

        false ->
            Validated
    end.

-file("src/etui/widgets/form.gleam", 293).
-spec is_submitted(form(any())) -> boolean().
-doc(~" True if the form was successfully submitted.").
is_submitted(F) ->
    erlang:element(4, F).

-file("src/etui/widgets/form.gleam", 298).
-spec reset(form(GGV)) -> form(GGV).
-doc(~" Reset all fields to empty, clear errors and submitted flag.").
reset(F) ->
    Fields = gleam@list:map(erlang:element(2, F), fun(Field) ->
        {field, erlang:element(2, Field), erlang:element(3, Field), ~"", erlang:element(5, Field), ~"", erlang:element(7, Field)}
    end),
    {form, Fields, 0, false, erlang:element(5, F), erlang:element(6, F), erlang:element(7, F), erlang:element(8, F), erlang:element(9, F), erlang:element(10, F)}.

-file("src/etui/widgets/form.gleam", 305).
-spec get_value(form(GGY), GGY) -> binary().
-doc(~" Get a field's current value by id. Returns \"\" if not found.").
get_value(F, Id) ->
    case gleam@list:find(erlang:element(2, F), fun(Field) ->
        erlang:element(2, Field) =:= Id
    end) of
        {ok, Field} ->
            erlang:element(4, Field);

        {error, _} ->
            ~""
    end.

-file("src/etui/widgets/form.gleam", 313).
-spec values(form(GHA)) -> list({GHA, binary()}).
-doc(~" Get all field values as `#(id, value)` pairs.").
values(F) ->
    gleam@list:map(erlang:element(2, F), fun(Field) ->
        {erlang:element(2, Field), erlang:element(4, Field)}
    end).

-file("src/etui/widgets/form.gleam", 365).
-spec render_field_row(etui@buffer:buffer(), etui@geometry:rect(), field(GHJ), form(GHJ), integer(), integer(), integer()) -> etui@buffer:buffer().
render_field_row(Buf, Area, Field, F, Lw, Field_idx, Y) ->
    Is_focused = Field_idx =:= erlang:element(3, F),
    Label_text = <<(etui@text:pad_right(etui@text:truncate(erlang:element(3, Field), Lw, ~""), Lw))/binary, " "/utf8>>,
    Value_x = (erlang:element(2, erlang:element(2, Area)) + Lw) + 1,
    Value_w = (erlang:element(2, erlang:element(3, Area)) - Lw) - 1,
    Value_w@1 = case Value_w < 0 of
        true ->
            0;

        false ->
            Value_w
    end,
    {Val_fg, Val_bg} = case Is_focused of
        true ->
            {erlang:element(8, F), erlang:element(9, F)};

        false ->
            {erlang:element(6, F), erlang:element(7, F)}
    end,
    Label_modifier = case Is_focused of
        true ->
            etui@style:bold();

        false ->
            etui@style:none()
    end,
    Buf1 = case Lw > 0 of
        false ->
            Buf;

        true ->
            etui@buffer:set_string(Buf, {position, erlang:element(2, erlang:element(2, Area)), Y}, Label_text, etui@style:new(erlang:element(6, F), erlang:element(7, F), Label_modifier))
    end,
    Padded_value = etui@text:pad_right(etui@text:truncate(erlang:element(4, Field), Value_w@1, ~""), Value_w@1),
    Buf2 = case Value_w@1 > 0 of
        false ->
            Buf1;

        true ->
            etui@buffer:set_string(Buf1, {position, Value_x, Y}, Padded_value, etui@style:new(Val_fg, Val_bg, etui@style:none()))
    end,
    Error_y = Y + 1,
    case ((erlang:element(6, Field) /= ~"") andalso (Error_y < (erlang:element(3, erlang:element(2, Area)) + erlang:element(3, erlang:element(3, Area))))) andalso (Value_w@1 > 0) of
        false ->
            Buf2;

        true ->
            etui@buffer:set_string(Buf2, {position, Value_x, Error_y}, etui@text:truncate(<<"  "/utf8, (erlang:element(6, Field))/binary>>, Value_w@1, ~""), etui@style:new(erlang:element(10, F), erlang:element(7, F), etui@style:none()))
    end.

-file("src/etui/widgets/form.gleam", 341).
-spec render_fields(etui@buffer:buffer(), etui@geometry:rect(), list(field(GHF)), form(GHF), integer(), integer(), integer()) -> etui@buffer:buffer().
render_fields(Buf, Area, Fields, F, Lw, Field_idx, Row) ->
    Row_height = 2,
    case Fields of
        [] ->
            Buf;

        [Field | Rest] ->
            Y = erlang:element(3, erlang:element(2, Area)) + Row,
            Fits = Y < (erlang:element(3, erlang:element(2, Area)) + erlang:element(3, erlang:element(3, Area))),
            Buf2 = case Fits of
                false ->
                    Buf;

                true ->
                    render_field_row(Buf, Area, Field, F, Lw, Field_idx, Y)
            end,
            render_fields(Buf2, Area, Rest, F, Lw, Field_idx + 1, Row + Row_height)
    end.

-file("src/etui/widgets/form.gleam", 451).
-spec compute_label_width(list(field(any()))) -> integer().
compute_label_width(Fields) ->
    gleam@list:fold(Fields, 0, fun(Acc, Field) ->
        W = etui@text:cell_width(erlang:element(3, Field)),
        case W > Acc of
            true ->
                W;

            false ->
                Acc
        end
    end).

-file("src/etui/widgets/form.gleam", 322).
-spec render(etui@buffer:buffer(), etui@geometry:rect(), form(any())) -> etui@buffer:buffer().
-doc(~" Render all fields as label + value rows. Each field takes 2 rows
 (value row + optional error row). Focused field is highlighted.").
render(Buf, Area, F) ->
    case ((erlang:element(2, erlang:element(3, Area)) =< 0) orelse (erlang:element(3, erlang:element(3, Area)) =< 0)) orelse gleam@list:is_empty(erlang:element(2, F)) of
        true ->
            Buf;

        false ->
            Lw = case erlang:element(5, F) of
                0 ->
                    compute_label_width(erlang:element(2, F));

                W ->
                    W
            end,
            render_fields(Buf, Area, erlang:element(2, F), F, Lw, 0, 0)
    end.

