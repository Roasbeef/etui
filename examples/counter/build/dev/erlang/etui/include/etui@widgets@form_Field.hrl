-record(field, {
    id :: any(),
    label :: binary(),
    value :: binary(),
    validator :: fun((binary()) -> {ok, nil} | {error, binary()}),
    error :: binary(),
    max_length :: integer()
}).
