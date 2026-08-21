-module(etui@terminal).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([open_viewport/1, close_viewport/2, draw_widget/3, with_buffer/2, set_cursor/2, hide_cursor/1, frame_ops/5, new_with_viewport/2, new/1, area/1, viewport/1, draw_with/2, draw/2, poll/2, restore/1]).
-export_type([viewport/0, cursor/0, frame/0, terminal/1]).

-type viewport() :: fullscreen | {inline, integer()} | {fixed, etui@geometry:rect()}.

-type cursor() :: cursor_untouched | cursor_hidden | {cursor_shown, etui@geometry:position()}.

-type frame() :: {frame, etui@geometry:rect(), etui@buffer:buffer(), cursor()}.

-opaque terminal(EQM) :: {terminal, etui@backend:backend(EQM), EQM, viewport(), etui@buffer:buffer(), boolean()}.

-file("src/etui/terminal.gleam", 66).
-spec viewport_area(viewport(), etui@backend:terminal_size()) -> etui@geometry:rect().
-doc(~" The rect a viewport occupies in a terminal of this size.").
viewport_area(Vp, Size) ->
    case Vp of
        fullscreen ->
            etui@geometry:rect_new(0, 0, erlang:element(2, Size), erlang:element(3, Size));

        {inline, Rows} ->
            H = gleam@int:clamp(Rows, 0, erlang:element(3, Size)),
            etui@geometry:rect_new(0, erlang:element(3, Size) - H, erlang:element(2, Size), H);

        {fixed, Area} ->
            etui@geometry:clamp(Area, etui@geometry:rect_new(0, 0, erlang:element(2, Size), erlang:element(3, Size)))
    end.

-file("src/etui/terminal.gleam", 81).
-spec may_clear(viewport()) -> boolean().
-doc(~" Only a full-screen app may clear the terminal. Anywhere else that would
 wipe scrollback the app does not own, so a repaint writes its own cells
 and touches nothing outside them.").
may_clear(Vp) ->
    case Vp of
        fullscreen ->
            true;

        _ ->
            false
    end.

-file("src/etui/terminal.gleam", 95).
-spec open_viewport(viewport()) -> list(etui@backend:render_op()).
-doc(~" Ops that make room for the viewport before the first frame.

 An inline viewport prints its own height in newlines, which scrolls
 whatever was on screen up and leaves the bottom rows blank for the app.
 Without it the first frame would draw over the last lines of output.

 Public alongside `close_viewport`; see there.").
open_viewport(Vp) ->
    case Vp of
        fullscreen ->
            [enter_alt_screen];

        {inline, Rows} ->
            [exit_alt_screen, {write, gleam@string:repeat(~"\n", gleam@int:max(0, Rows))}];

        {fixed, _} ->
            [exit_alt_screen]
    end.

-file("src/etui/terminal.gleam", 113).
-spec close_viewport(viewport(), etui@geometry:rect()) -> list(etui@backend:render_op()).
-doc(~" Ops that hand the terminal back, once the app is done.

 Public for the same reason as `frame_ops`: what a viewport does on the way
 out is worth being able to check without a terminal to do it to, and for an
 inline app it is the visible difference from a full-screen one.").
close_viewport(Vp, Area) ->
    case Vp of
        fullscreen ->
            [{write, etui@cursor:show()}];

        _ ->
            [{move_cursor, 0, etui@geometry:bottom(Area) - 1}, {write, <<"\r\n"/utf8, (etui@cursor:show())/binary>>}]
    end.

-file("src/etui/terminal.gleam", 148).
-spec draw_widget(frame(), etui@geometry:rect(), fun((etui@buffer:buffer(), etui@geometry:rect()) -> etui@buffer:buffer())) -> frame().
-doc(~" Draw a widget into part of the frame.").
draw_widget(Frame, Area, W) ->
    {frame, erlang:element(2, Frame), W(erlang:element(3, Frame), Area), erlang:element(4, Frame)}.

-file("src/etui/terminal.gleam", 154).
-spec with_buffer(frame(), etui@buffer:buffer()) -> frame().
-doc(~" Replace the frame's buffer, for code that renders by returning a buffer
 rather than by applying widgets.").
with_buffer(Frame, Buf) ->
    {frame, erlang:element(2, Frame), Buf, erlang:element(4, Frame)}.

-file("src/etui/terminal.gleam", 159).
-spec set_cursor(frame(), etui@geometry:position()) -> frame().
-doc(~" Put the cursor at `pos` when this frame is drawn.").
set_cursor(Frame, Pos) ->
    {frame, erlang:element(2, Frame), erlang:element(3, Frame), {cursor_shown, Pos}}.

-file("src/etui/terminal.gleam", 164).
-spec hide_cursor(frame()) -> frame().
-doc(~" Hide the cursor when this frame is drawn.").
hide_cursor(Frame) ->
    {frame, erlang:element(2, Frame), erlang:element(3, Frame), cursor_hidden}.

-file("src/etui/terminal.gleam", 180).
-spec frame_ops(etui@buffer:buffer(), etui@buffer:buffer(), boolean(), cursor(), boolean()) -> list(etui@backend:render_op()).
-doc(~" The render ops that take the terminal from `prev` to `curr`.

 A first frame, at start-up or after a resize, repaints everything: what the
 terminal is showing is unknown, so there is nothing to diff against. Every
 frame after that emits only the cells that changed.

 Public because it is worth being able to check what a frame will emit
 without a terminal to emit it into, which is how the diffing and cursor
 rules are tested. `draw` is what an app calls.").
frame_ops(Prev, Curr, First_frame, Cur, Clear_first) ->
    Ansi = case First_frame of
        true ->
            etui@buffer:to_ansi(Curr);

        false ->
            etui@buffer:diff_to_ansi(Prev, Curr)
    end,
    Cursor_ansi = case Cur of
        cursor_untouched ->
            ~"";

        cursor_hidden ->
            etui@cursor:hide();

        {cursor_shown, Pos} ->
            <<<<(etui@cursor:hide())/binary, (etui@cursor:move_to(erlang:element(3, Pos) + 1, erlang:element(2, Pos) + 1))/binary>>/binary, (etui@cursor:show())/binary>>
    end,
    case {Ansi, Cursor_ansi} of
        {~"", ~""} ->
            [];

        {~"", Only_cursor} ->
            [{write, Only_cursor}];

        {_, _} ->
            case First_frame andalso Clear_first of
                true ->
                    [clear_screen, {move_cursor, 0, 0}, {write, <<Ansi/binary, Cursor_ansi/binary>>}];

                false ->
                    [{write, <<Ansi/binary, Cursor_ansi/binary>>}]
            end
    end.

-file("src/etui/terminal.gleam", 212).
-spec blank(etui@geometry:rect()) -> etui@buffer:buffer().
blank(Area) ->
    etui@buffer:buffer_new(Area).

-file("src/etui/terminal.gleam", 249).
-spec new_with_viewport(etui@backend:backend(EQV), viewport()) -> {ok, terminal(EQV)} | {error, etui@backend:error()}.
-doc(~" Open a terminal that uses only part of the screen.

 ```gleam
 // A five-row progress area under whatever the shell has already printed
 let assert Ok(term) = terminal.new_with_viewport(default.new(), terminal.Inline(5))
 ```").
new_with_viewport(B, Vp) ->
    case (erlang:element(2, B))() of
        {ok, Bs} ->
            {Size, Bs2} = case (erlang:element(5, B))(Bs) of
                {ok, {Sz, Bs1}} ->
                    {Sz, Bs1};

                _ ->
                    {{terminal_size, 80, 24}, Bs}
            end,
            Area = viewport_area(Vp, Size),
            Opening = lists:append(open_viewport(Vp), [{write, etui@cursor:hide()}]),
            Opened = case (erlang:element(3, B))(Bs2, Opening) of
                {ok, Bs3} ->
                    Bs3;

                _ ->
                    Bs2
            end,
            {ok, {terminal, B, Opened, Vp, blank(Area), true}};

        {error, E} ->
            {error, E}
    end.

-file("src/etui/terminal.gleam", 236).
-spec new(etui@backend:backend(EQQ)) -> {ok, terminal(EQQ)} | {error, etui@backend:error()}.
-doc(~" Open a terminal that takes over the whole screen.").
new(B) ->
    new_with_viewport(B, fullscreen).

-file("src/etui/terminal.gleam", 283).
-spec area(terminal(any())) -> etui@geometry:rect().
-doc(~" The area a frame will be given, which is the viewport rather than always
 the whole screen.").
area(Term) ->
    etui@buffer:area(erlang:element(5, Term)).

-file("src/etui/terminal.gleam", 289).
-spec viewport(terminal(any())) -> viewport().
-doc(~" The viewport this terminal was opened with.").
viewport(Term) ->
    erlang:element(4, Term).

-file("src/etui/terminal.gleam", 322).
-spec draw_with(terminal(ERJ), fun((frame()) -> {frame(), ERL})) -> {ok, {terminal(ERJ), ERL}} | {error, etui@backend:error()}.
-doc(~" Draw one frame and carry a value back out of it.

 A frame closure works out things the rest of your program wants: the rects
 the layout produced, so a click can be matched against them, or the state a
 list settled on once it knew how tall it was. Without a way out those die
 inside the closure and have to be computed a second time.

 ```gleam
 let assert Ok(#(term, panes)) =
   terminal.draw_with(term, fn(frame) {
     let panes = geometry.split_h(frame.area, [Fill, Fill])
     #(draw_panes(frame, panes), panes)
   })
 // `panes` is now available for hit-testing the next mouse event
 ```").
draw_with(Term, Build) ->
    Screen = area(Term),
    {Frame, Carried} = Build({frame, Screen, etui@buffer:buffer_new(Screen), cursor_untouched}),
    Ops = frame_ops(erlang:element(5, Term), erlang:element(3, Frame), erlang:element(6, Term), erlang:element(4, Frame), may_clear(erlang:element(4, Term))),
    case (erlang:element(3, erlang:element(2, Term)))(erlang:element(3, Term), Ops) of
        {ok, Bs} ->
            {ok, {{terminal, erlang:element(2, Term), Bs, erlang:element(4, Term), erlang:element(3, Frame), false}, Carried}};

        {error, E} ->
            {error, E}
    end.

-file("src/etui/terminal.gleam", 296).
-spec draw(terminal(ERE), fun((frame()) -> frame())) -> {ok, terminal(ERE)} | {error, etui@backend:error()}.
-doc(~" Draw one frame. `build` is handed an empty frame the size of the screen and
 returns it filled in.").
draw(Term, Build) ->
    case draw_with(Term, fun(Frame) ->
        {Build(Frame), nil}
    end) of
        {ok, {Next, nil}} ->
            {ok, Next};

        {error, E} ->
            {error, E}
    end.

-file("src/etui/terminal.gleam", 513).
-spec absorb(terminal(ERW), etui@backend:input_event()) -> terminal(ERW).
absorb(Term, Event) ->
    case Event of
        {resize, W, H} ->
            {terminal, erlang:element(2, Term), erlang:element(3, Term), erlang:element(4, Term), blank(viewport_area(erlang:element(4, Term), {terminal_size, W, H})), true};

        _ ->
            Term
    end.

-file("src/etui/terminal.gleam", 356).
-spec poll(terminal(ERP), integer()) -> {ok, {etui@backend:input_event(), terminal(ERP)}} | {error, etui@backend:error()}.
-doc(~" Wait up to `timeout_ms` for an event.

 A resize is reported like any other event, and also resets the terminal's
 idea of what is on screen, so the next `draw` repaints at the new size.").
poll(Term, Timeout_ms) ->
    case (erlang:element(4, erlang:element(2, Term)))(erlang:element(3, Term), Timeout_ms) of
        {ok, {Event, Bs}} ->
            {ok, {Event, absorb({terminal, erlang:element(2, Term), Bs, erlang:element(4, Term), erlang:element(5, Term), erlang:element(6, Term)}, Event)}};

        {error, E} ->
            {error, E}
    end.

-file("src/etui/terminal.gleam", 368).
-spec restore(terminal(any())) -> nil.
-doc(~" Leave the alternate screen, restore the cursor and hand the terminal back.").
restore(Term) ->
    _ = (erlang:element(3, erlang:element(2, Term)))(erlang:element(3, Term), close_viewport(erlang:element(4, Term), area(Term))),
    (erlang:element(6, erlang:element(2, Term)))(erlang:element(3, Term)).

