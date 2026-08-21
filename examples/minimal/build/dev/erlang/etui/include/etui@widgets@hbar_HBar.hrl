-record(h_bar, {
    items :: list(etui@widgets@hbar:h_bar_item()),
    max_val :: integer(),
    fill :: etui@widgets@hbar:h_bar_fill(),
    label_width :: integer(),
    show_value :: boolean(),
    bar_char :: binary(),
    empty_char :: binary(),
    bg :: etui@style:color(),
    period :: integer()
}).
