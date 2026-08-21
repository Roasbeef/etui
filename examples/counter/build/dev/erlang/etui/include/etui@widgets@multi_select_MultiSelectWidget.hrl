-record(multi_select_widget, {
    items :: list(binary()),
    cursor_style :: etui@style:style(),
    selected_style :: etui@style:style(),
    checked_mark :: binary(),
    unchecked_mark :: binary(),
    cursor_mark :: binary(),
    max :: integer(),
    fg :: etui@style:color(),
    bg :: etui@style:color()
}).
