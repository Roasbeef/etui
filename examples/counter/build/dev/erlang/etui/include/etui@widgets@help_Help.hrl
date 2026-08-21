-record(help, {
    bindings :: list(etui@widgets@help:binding()),
    mode :: etui@widgets@help:help_mode(),
    separator :: binary(),
    key_fg :: etui@style:color(),
    description_fg :: etui@style:color(),
    bg :: etui@style:color()
}).
