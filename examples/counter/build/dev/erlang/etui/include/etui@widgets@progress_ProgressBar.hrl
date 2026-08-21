-record(progress_bar, {
    mode :: etui@widgets@progress:progress_mode(),
    label :: binary(),
    filled_char :: binary(),
    empty_char :: binary(),
    segment_width :: integer(),
    fg :: etui@style:color(),
    bg :: etui@style:color(),
    filled_modifier :: etui@style:modifier(),
    empty_modifier :: etui@style:modifier()
}).
