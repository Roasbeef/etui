-module(etui@braille).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([new/0, set_pixel/5, bit/2, put/4, flush/4]).

-file("src/etui/braille.gleam", 20).
-spec new() -> gleam@dict:dict({integer(), integer()}, {integer(), etui@style:color()}).
-doc(~" Empty pixel grid.").
new() ->
    maps:new().

-file("src/etui/braille.gleam", 26).
-spec set_pixel(gleam@dict:dict({integer(), integer()}, {integer(), etui@style:color()}), integer(), integer(), integer(), etui@style:color()) -> gleam@dict:dict({integer(), integer()}, {integer(), etui@style:color()}).
-doc(~" Set a pixel at terminal-cell (char_x, char_y), accumulating its bit into
 the existing mask. Color overrides any prior color for that cell.").
set_pixel(Pixels, Char_x, Char_y, Bit, Fg) ->
    Key = {Char_x, Char_y},
    Existing = case gleam_stdlib:map_get(Pixels, Key) of
        {ok, {M, _}} ->
            M;

        {error, _} ->
            0
    end,
    gleam@dict:insert(Pixels, Key, {erlang:'bor'(Existing, Bit), Fg}).

-file("src/etui/braille.gleam", 48).
-spec bit(integer(), integer()) -> integer().
-doc(~" Bitmask bit for the dot at (col, row) inside a 2×4 braille cell.
 Layout (Unicode braille dot numbering):
   col 0  col 1
   row 0    1     8
   row 1    2    16
   row 2    4    32
   row 3   64   128").
bit(Col, Row) ->
    case {Col, Row} of
        {0, 0} ->
            1;

        {0, 1} ->
            2;

        {0, 2} ->
            4;

        {0, 3} ->
            64;

        {1, 0} ->
            8;

        {1, 1} ->
            16;

        {1, 2} ->
            32;

        {1, 3} ->
            128;

        {_, _} ->
            0
    end.

-file("src/etui/braille.gleam", 64).
-spec put(gleam@dict:dict({integer(), integer()}, {integer(), etui@style:color()}), integer(), integer(), etui@style:color()) -> gleam@dict:dict({integer(), integer()}, {integer(), etui@style:color()}).
-doc(~" Write a single pixel at absolute braille-pixel coords (px, py) into the
 pixel grid. Out-of-bounds coords (px < 0 or py < 0) are dropped.").
put(Pixels, Px, Py, Fg) ->
    case (Px < 0) orelse (Py < 0) of
        true ->
            Pixels;

        false ->
            set_pixel(Pixels, Px div 2, Py div 4, bit(Px rem 2, Py rem 4), Fg)
    end.

-file("src/etui/braille.gleam", 73).
-spec flush(etui@buffer:buffer(), etui@geometry:rect(), gleam@dict:dict({integer(), integer()}, {integer(), etui@style:color()}), etui@style:color()) -> etui@buffer:buffer().
-doc(~" Flush the pixel grid into a buffer at the given area's origin.
 Each populated cell becomes one braille glyph.").
flush(Buf, Area, Pixels, Bg) ->
    gleam@dict:fold(Pixels, Buf, fun(B, Key, Val) ->
        {Char_x, Char_y} = Key,
        {Mask, Fg} = Val,
        Ch = case gleam@string:utf_codepoint(10240 + Mask) of
            {ok, Cp} ->
                gleam_stdlib:utf_codepoint_list_to_string([Cp]);

            {error, _} ->
                ~"·"
        end,
        etui@buffer:set_string(B, {position, erlang:element(2, erlang:element(2, Area)) + Char_x, erlang:element(3, erlang:element(2, Area)) + Char_y}, Ch, etui@style:new(Fg, Bg, etui@style:none()))
    end).

