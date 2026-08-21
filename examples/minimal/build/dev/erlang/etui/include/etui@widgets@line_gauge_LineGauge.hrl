-record(line_gauge, {
    percent :: integer(),
    label :: binary(),
    line_set :: etui@widgets@line_gauge:line_set(),
    fg :: etui@style:color(),
    bg :: etui@style:color(),
    filled_modifier :: etui@style:modifier(),
    unfilled_modifier :: etui@style:modifier()
}).
