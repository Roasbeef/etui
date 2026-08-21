-record(paginator, {
    current :: integer(),
    total :: integer(),
    page_size :: integer(),
    style :: etui@widgets@paginator:paginator_style(),
    active_char :: binary(),
    inactive_char :: binary(),
    fg :: etui@style:color(),
    bg :: etui@style:color()
}).
