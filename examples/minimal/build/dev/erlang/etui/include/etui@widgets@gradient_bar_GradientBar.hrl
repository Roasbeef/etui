-record(gradient_bar, {
    fill :: etui@widgets@gradient_bar:gradient_fill(),
    filled_char :: binary(),
    empty_char :: binary(),
    percent :: integer(),
    modifier :: etui@style:modifier(),
    bg :: etui@style:color(),
    period :: integer()
}).
