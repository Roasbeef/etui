-record(backend, {
    init :: fun(() -> {ok, any()} | {error, etui@backend:error()}),
    render :: fun((any(), list(etui@backend:render_op())) -> {ok, any()} | {error, etui@backend:error()}),
    poll :: fun((any(), integer()) -> {ok, {etui@backend:input_event(), any()}} | {error, etui@backend:error()}),
    next_size :: fun((any()) -> {ok, {etui@backend:terminal_size(), any()}} | {error, etui@backend:error()}),
    cleanup :: fun((any()) -> nil)
}).
