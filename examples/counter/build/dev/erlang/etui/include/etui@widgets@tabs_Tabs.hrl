-record(tabs, {
    labels :: list(binary()),
    active :: integer(),
    fg :: etui@style:color(),
    bg :: etui@style:color(),
    active_style :: etui@style:style(),
    divider :: binary(),
    padding :: integer()
}).
