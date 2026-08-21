-module(etui@cursor).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([set_shape/1, show/0, hide/0, move_to/2, save/0, restore/0]).
-export_type([cursor_shape/0]).

-type cursor_shape() :: block_blink | block | underline_blink | underline | bar_blink | bar.

-file("src/etui/cursor.gleam", 17).
-spec set_shape(cursor_shape()) -> binary().
-doc(~" ANSI sequence to change the cursor shape.").
set_shape(Shape) ->
    case Shape of
        block_blink ->
            ~"\x{001B}[1 q";

        block ->
            ~"\x{001B}[2 q";

        underline_blink ->
            ~"\x{001B}[3 q";

        underline ->
            ~"\x{001B}[4 q";

        bar_blink ->
            ~"\x{001B}[5 q";

        bar ->
            ~"\x{001B}[6 q"
    end.

-file("src/etui/cursor.gleam", 31).
-spec show() -> binary().
show() ->
    ~"\x{001B}[?25h".

-file("src/etui/cursor.gleam", 35).
-spec hide() -> binary().
hide() ->
    ~"\x{001B}[?25l".

-file("src/etui/cursor.gleam", 43).
-spec move_to(integer(), integer()) -> binary().
-doc(~" Move cursor to 1-based (row, col) position.").
move_to(Row, Col) ->
    <<<<<<<<"\x{001B}["/utf8, (erlang:integer_to_binary(Row))/binary>>/binary, ";"/utf8>>/binary, (erlang:integer_to_binary(Col))/binary>>/binary, "H"/utf8>>.

-file("src/etui/cursor.gleam", 48).
-spec save() -> binary().
-doc(~" Save cursor position.").
save() ->
    ~"\x{001B}[s".

-file("src/etui/cursor.gleam", 53).
-spec restore() -> binary().
-doc(~" Restore cursor position.").
restore() ->
    ~"\x{001B}[u".

