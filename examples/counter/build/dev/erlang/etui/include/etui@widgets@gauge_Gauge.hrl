-record(gauge, {
    percent :: integer(),
    label :: binary(),
    filled_char :: binary(),
    empty_char :: binary(),
    fg :: etui@style:color(),
    bg :: etui@style:color(),
    filled_modifier :: etui@style:modifier(),
    empty_modifier :: etui@style:modifier()
}).
