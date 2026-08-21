-record(erlang_terminal_state, {
    raw_mode_active :: boolean(),
    cols :: integer(),
    rows :: integer(),
    mouse :: boolean(),
    last_size_check :: integer(),
    last_size_change :: integer(),
    pending :: binary(),
    queue :: list(etui@backend:input_event())
}).
