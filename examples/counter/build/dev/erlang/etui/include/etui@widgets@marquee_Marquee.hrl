-record(marquee, {
    text :: binary(),
    speed :: integer(),
    separator :: binary(),
    fg :: etui@style:color(),
    bg :: etui@style:color(),
    modifier :: etui@style:modifier()
}).
