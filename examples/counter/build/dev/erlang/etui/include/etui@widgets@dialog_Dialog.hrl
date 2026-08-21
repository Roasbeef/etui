-record(dialog, {
    message :: binary(),
    confirm_label :: binary(),
    cancel_label :: binary(),
    width :: integer(),
    height :: integer(),
    fg :: etui@style:color(),
    bg :: etui@style:color(),
    confirm_style :: etui@style:style(),
    cancel_style :: etui@style:style(),
    focused_style :: etui@style:style(),
    border :: etui@widgets@block:border()
}).
