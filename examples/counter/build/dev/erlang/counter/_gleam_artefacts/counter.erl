-module(counter).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([main/0]).
-export_type([model/0]).

-type model() :: {model, integer(), boolean(), integer(), integer()}.

-file("src/counter.gleam", 46).
-spec update(etui@backend:input_event(), model()) -> model().
update(Event, Model) ->
    case Event of
        {key_press, ~"q"} ->
            {model, erlang:element(2, Model), true, erlang:element(4, Model), erlang:element(5, Model)};

        {key_press, ~" "} ->
            {model, erlang:element(2, Model) + 1, erlang:element(3, Model), erlang:element(4, Model), erlang:element(5, Model)};

        {resize, W, H} ->
            {model, erlang:element(2, Model), erlang:element(3, Model), W, H};

        _ ->
            Model
    end.

-file("src/counter.gleam", 26).
-spec view(model(), etui@geometry:rect()) -> etui@buffer:buffer().
view(Model, Screen) ->
    Chunks = etui@geometry:split(horizontal, Screen, [{percentage, 30}, fill]),
    Left = case Chunks of
        [L | _] ->
            L;

        _ ->
            Screen
    end,
    Right = case Chunks of
        [_, R | _] ->
            R;

        _ ->
            Screen
    end,
    Para = etui@widgets@paragraph:paragraph_new(<<<<"Count: "/utf8, (erlang:integer_to_binary(erlang:element(2, Model)))/binary>>/binary, "  (space +1, q quit)"/utf8>>),
    Blk = begin
        _pipe = etui@widgets@block:block_new(),
        _pipe@1 = etui@widgets@block:with_border(_pipe, rounded),
        etui@widgets@block:with_title(_pipe@1, ~"Main", top)
    end,
    Sidebar = begin
        _pipe@2 = etui@widgets@block:block_new(),
        _pipe@3 = etui@widgets@block:with_border(_pipe@2, single),
        etui@widgets@block:with_title(_pipe@3, ~"Side", top)
    end,
    _pipe@4 = etui@buffer:buffer_new(Screen),
    _pipe@5 = etui@widgets@block:render(_pipe@4, Left, Sidebar),
    _pipe@6 = etui@widgets@block:render(_pipe@5, Right, Blk),
    etui@widgets@paragraph:render(_pipe@6, etui@widgets@block:inner(Right, Blk), Para).

-file("src/counter.gleam", 14).
-spec main() -> etui@app:app_result(model()).
main() ->
    _ = etui@app:run_buffered(etui@backend@default:new(), {model, 0, false, 80, 24}, fun view/2, fun update/2, fun(M) ->
        erlang:element(3, M)
    end, 16).

