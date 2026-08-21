-record(block, {
    border :: etui@widgets@block:border(),
    title :: binary(),
    title_spans :: list(etui@span:span()),
    title_position :: etui@widgets@block:title_position(),
    title_alignment :: etui@text:alignment(),
    padding_top :: integer(),
    padding_bottom :: integer(),
    padding_left :: integer(),
    padding_right :: integer(),
    fg :: etui@style:color(),
    bg :: etui@style:color(),
    fill_bg :: boolean()
}).
