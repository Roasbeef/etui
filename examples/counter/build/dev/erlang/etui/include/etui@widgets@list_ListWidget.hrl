-record(list_widget, {
    items :: list(etui@span:line()),
    fg :: etui@style:color(),
    bg :: etui@style:color(),
    highlight_style :: etui@style:style(),
    blink_period :: integer()
}).
