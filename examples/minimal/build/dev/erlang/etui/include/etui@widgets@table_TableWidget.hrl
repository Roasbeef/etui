-record(table_widget, {
    rows :: list(list(binary())),
    col_widths :: list(integer()),
    col_constraints :: list(etui@geometry:constraint()),
    show_header :: boolean(),
    fg :: etui@style:color(),
    bg :: etui@style:color(),
    highlight_style :: etui@style:style(),
    blink_period :: integer()
}).
