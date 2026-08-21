-module(minimal).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([main/0]).
-export_type([model/0]).

-type model() :: {model, boolean(), integer(), integer()}.

-file("src/minimal.gleam", 32).
-spec update(etui@backend:input_event(), model()) -> model().
update(Event, Model) ->
    case Event of
        {resize, W, H} ->
            {model, erlang:element(2, Model), W, H};

        {key_press, ~"q"} ->
            {model, true, erlang:element(3, Model), erlang:element(4, Model)};

        _ ->
            Model
    end.

-file("src/minimal.gleam", 24).
-spec view(model(), etui@geometry:rect()) -> etui@buffer:buffer().
view(_, Screen) ->
    _pipe = etui@buffer:buffer_new(Screen),
    etui@widgets@paragraph:render(_pipe, Screen, etui@widgets@paragraph:paragraph_new(~"Hello, étui!  Press q to quit.")).

-file("src/minimal.gleam", 12).
-spec main() -> etui@app:app_result(model()).
main() ->
    _ = etui@app:run_buffered(etui@backend@default:new(), {model, false, 80, 24}, fun view/2, fun update/2, fun(M) ->
        erlang:element(2, M)
    end, 16).

