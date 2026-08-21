-module(etui@app).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([run/6, run_buffered/6, run_animated/6, run_buffered_cursor/6]).
-export_type([app_result/1]).

-type app_result(EWE) :: {success, EWE} | {error, binary()}.

-file("src/etui/app.gleam", 41).
-spec initial_resize(etui@geometry:rect()) -> etui@backend:input_event().
initial_resize(Screen) ->
    {resize, erlang:element(2, erlang:element(3, Screen)), erlang:element(3, erlang:element(3, Screen))}.

-file("src/etui/app.gleam", 46).
-spec buffered_frame(etui@terminal:frame(), etui@buffer:buffer()) -> etui@terminal:frame().
buffered_frame(Frame, Rendered) ->
    etui@terminal:with_buffer(Frame, Rendered).

-file("src/etui/app.gleam", 50).
-spec cursor_frame(etui@terminal:frame(), {etui@buffer:buffer(), {ok, etui@geometry:position()} | {error, nil}}) -> etui@terminal:frame().
cursor_frame(Frame, Rendered) ->
    {Buf, Pos} = Rendered,
    Placed = etui@terminal:with_buffer(Frame, Buf),
    case Pos of
        {ok, P} ->
            etui@terminal:set_cursor(Placed, P);

        _ ->
            etui@terminal:hide_cursor(Placed)
    end.

-file("src/etui/app.gleam", 119).
-spec loop(etui@backend:backend(EWN), EWN, EWP, fun((EWP) -> list(etui@backend:render_op())), fun((etui@backend:input_event(), EWP) -> EWP), fun((EWP) -> boolean()), integer()) -> {EWP, EWN}.
loop(B, Bs, State, Render, On_event, Should_quit, Poll_timeout_ms) ->
    case (erlang:element(3, B))(Bs, Render(State)) of
        {ok, Bs2} ->
            case (erlang:element(4, B))(Bs2, Poll_timeout_ms) of
                {ok, {Event, Bs3}} ->
                    Next = On_event(Event, State),
                    case Should_quit(Next) of
                        true ->
                            {Next, Bs3};

                        false ->
                            loop(B, Bs3, Next, Render, On_event, Should_quit, Poll_timeout_ms)
                    end;

                _ ->
                    {State, Bs2}
            end;

        _ ->
            {State, Bs}
    end.

-file("src/etui/app.gleam", 84).
-spec run(etui@backend:backend(any()), EWK, fun((EWK) -> list(etui@backend:render_op())), fun((etui@backend:input_event(), EWK) -> EWK), fun((EWK) -> boolean()), integer()) -> app_result(EWK).
-doc(~" Run the app loop over raw render ops.

 Lifecycle:
 1. `b.init()`, enter raw mode, alt screen.
 2. Loop: `render(state)` → emit ops → `b.poll()` → `on_event()`.
 3. Exit when `should_quit(state)` returns `True`.
 4. `b.cleanup()`, always runs, even on panic.

 ```gleam
 app.run(
   default.new(),
   Model(count: 0),
   fn(m) { [Write(int.to_string(m.count))] },
   fn(ev, m) { case ev { KeyPress(\"q\") -> m KeyPress(_) -> Model(count: m.count + 1) _ -> m } },
   fn(m) { m.count >= 10 },
   16,
 )
 ```").
run(B, Init_state, Render, On_event, Should_quit, Poll_timeout_ms) ->
    case (erlang:element(2, B))() of
        {ok, Bs} ->
            etui_run_ffi:with_cleanup(fun() ->
                {Final_state, Final_bs} = loop(B, Bs, Init_state, Render, On_event, Should_quit, Poll_timeout_ms),
                (erlang:element(6, B))(Final_bs),
                {success, Final_state}
            end, fun() ->
                (erlang:element(6, B))(Bs)
            end);

        _ ->
            {error, ~"Terminal init failed"}
    end.

-file("src/etui/app.gleam", 186).
-spec drive_loop(etui@terminal:terminal(EWV), EWX, fun((etui@backend:input_event(), EWX) -> EWX), fun((EWX) -> boolean()), integer(), fun((etui@terminal:frame(), EWX, etui@anim:anim_state()) -> etui@terminal:frame()), etui@anim:anim_state()) -> {EWX, etui@terminal:terminal(EWV)}.
drive_loop(Term, State, On_event, Should_quit, Poll_timeout_ms, Build, Anim_state) ->
    case etui@terminal:draw(Term, fun(Frame) ->
        Build(Frame, State, Anim_state)
    end) of
        {ok, Drawn} ->
            case etui@terminal:poll(Drawn, Poll_timeout_ms) of
                {ok, {Event, Polled}} ->
                    Next = On_event(Event, State),
                    case Should_quit(Next) of
                        true ->
                            {Next, Polled};

                        false ->
                            drive_loop(Polled, Next, On_event, Should_quit, Poll_timeout_ms, Build, etui@anim:tick(Anim_state))
                    end;

                _ ->
                    {State, Drawn}
            end;

        _ ->
            {State, Term}
    end.

-file("src/etui/app.gleam", 152).
-spec drive(etui@backend:backend(any()), EWT, fun((etui@backend:input_event(), EWT) -> EWT), fun((EWT) -> boolean()), integer(), fun((etui@terminal:frame(), EWT, etui@anim:anim_state()) -> etui@terminal:frame())) -> app_result(EWT).
drive(B, Init_state, On_event, Should_quit, Poll_timeout_ms, Build) ->
    case etui@terminal:new(B) of
        {ok, Term} ->
            etui_run_ffi:with_cleanup(fun() ->
                Started = On_event(initial_resize(etui@terminal:area(Term)), Init_state),
                {Final_state, Final_term} = drive_loop(Term, Started, On_event, Should_quit, Poll_timeout_ms, Build, etui@anim:anim_new()),
                etui@terminal:restore(Final_term),
                {success, Final_state}
            end, fun() ->
                etui@terminal:restore(Term)
            end);

        _ ->
            {error, ~"Terminal init failed"}
    end.

-file("src/etui/app.gleam", 242).
-spec run_buffered(etui@backend:backend(any()), EXB, fun((EXB, etui@geometry:rect()) -> etui@buffer:buffer()), fun((etui@backend:input_event(), EXB) -> EXB), fun((EXB) -> boolean()), integer()) -> app_result(EXB).
-doc(~" High-level app loop. The render function produces a `Buffer`; the loop
 diffs it against the previous frame and emits only the changed cells.

 First frame: full repaint. Subsequent frames: diff. On `Resize`: full
 repaint at the new size.

 ```gleam
 app.run_buffered(
   default.new(),
   Model(count: 0),
   fn(m, screen) {
     buffer.buffer_new(screen)
     |> paragraph.render(screen, paragraph.paragraph_new(int.to_string(m.count)))
   },
   fn(ev, m) { case ev { KeyPress(\"q\") -> m _ -> m } },
   fn(m) { m.quit },
   16,
 )
 ```").
run_buffered(B, Init_state, Render, On_event, Should_quit, Poll_timeout_ms) ->
    drive(B, Init_state, On_event, Should_quit, Poll_timeout_ms, fun(F, S, _) ->
        buffered_frame(F, Render(S, erlang:element(2, F)))
    end).

-file("src/etui/app.gleam", 273).
-spec run_animated(etui@backend:backend(any()), EXF, fun((EXF, etui@geometry:rect(), etui@anim:anim_state()) -> etui@buffer:buffer()), fun((etui@backend:input_event(), EXF) -> EXF), fun((EXF) -> boolean()), integer()) -> app_result(EXF).
-doc(~" Like `run_buffered` but passes an `anim.AnimState` to the render function,
 auto-ticked every frame. Use when your UI has spinners, blinking widgets,
 marquees, or any frame-dependent animation, no manual tick needed.

 ```gleam
 app.run_animated(
   default.new(),
   Model(quit: False),
   fn(m, screen, anim_state) {
     buffer.buffer_new(screen)
     |> spinner.render(area, spinner.spinner_new() |> spinner.with_frame(anim_state.frame))
   },
   fn(ev, m) { case ev { backend.KeyPress(\"q\") -> Model(quit: True) _ -> m } },
   fn(m) { m.quit },
   16,
 )
 ```").
run_animated(B, Init_state, Render, On_event, Should_quit, Poll_timeout_ms) ->
    drive(B, Init_state, On_event, Should_quit, Poll_timeout_ms, fun(F, S, Anim_st) ->
        buffered_frame(F, Render(S, erlang:element(2, F), Anim_st))
    end).

-file("src/etui/app.gleam", 298).
-spec run_buffered_cursor(etui@backend:backend(any()), EXJ, fun((EXJ, etui@geometry:rect()) -> {etui@buffer:buffer(), {ok, etui@geometry:position()} | {error, nil}}), fun((etui@backend:input_event(), EXJ) -> EXJ), fun((EXJ) -> boolean()), integer()) -> app_result(EXJ).
-doc(~" Like `run_buffered` but the render function also returns where the hardware
 cursor belongs, as `Result(geometry.Position, Nil)`.

 - `Ok(pos)` shows the cursor at `pos` (0-based). Use for text inputs and
   text areas where the user needs to see the insertion point.
 - `Error(Nil)` hides it. Use for read-only views.").
run_buffered_cursor(B, Init_state, Render, On_event, Should_quit, Poll_timeout_ms) ->
    drive(B, Init_state, On_event, Should_quit, Poll_timeout_ms, fun(F, S, _) ->
        cursor_frame(F, Render(S, erlang:element(2, F)))
    end).

