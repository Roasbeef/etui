-record(form, {
    fields :: list(etui@widgets@form:field(any())),
    focused :: integer(),
    submitted :: boolean(),
    label_width :: integer(),
    fg :: etui@style:color(),
    bg :: etui@style:color(),
    focused_fg :: etui@style:color(),
    focused_bg :: etui@style:color(),
    error_fg :: etui@style:color()
}).
