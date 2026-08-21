-record(sparkline, {
    data :: list(integer()),
    max_val :: integer(),
    fill :: etui@widgets@sparkline:spark_fill(),
    bg :: etui@style:color(),
    modifier :: etui@style:modifier(),
    period :: integer()
}).
