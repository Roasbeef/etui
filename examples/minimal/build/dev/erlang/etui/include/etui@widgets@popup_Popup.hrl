-record(popup, {
    width :: integer(),
    height :: integer(),
    title :: binary(),
    border :: etui@widgets@block:border(),
    fg :: etui@style:color(),
    bg :: etui@style:color()
}).
