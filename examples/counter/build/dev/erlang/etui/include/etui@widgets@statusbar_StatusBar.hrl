-record(status_bar, {
    left :: list(etui@span:line()),
    center :: list(etui@span:line()),
    right :: list(etui@span:line()),
    fg :: etui@style:color(),
    bg :: etui@style:color()
}).
