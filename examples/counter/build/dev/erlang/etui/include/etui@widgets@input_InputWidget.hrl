-record(input_widget, {
    max_length :: integer(),
    placeholder :: binary(),
    fg :: etui@style:color(),
    bg :: etui@style:color(),
    validator :: fun((binary()) -> {ok, nil} | {error, binary()}),
    error_fg :: etui@style:color(),
    prompt :: binary(),
    password :: boolean(),
    mask :: binary()
}).
