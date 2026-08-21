-record(scrollbar, {
    total :: integer(),
    visible :: integer(),
    offset :: integer(),
    track_char :: binary(),
    thumb_char :: binary(),
    arrow_start :: binary(),
    arrow_end :: binary(),
    fg :: etui@style:color(),
    bg :: etui@style:color(),
    thumb_fg :: etui@style:color(),
    thumb_bg :: etui@style:color()
}).
