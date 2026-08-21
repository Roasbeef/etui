-record(chart, {
    data :: list(integer()),
    max_val :: integer(),
    fill :: etui@widgets@chart:chart_fill(),
    bar_width :: integer(),
    gap :: integer(),
    bar_char :: binary(),
    bg :: etui@style:color(),
    period :: integer()
}).
