-record(notification_queue, {
    items :: list(etui@widgets@notification:notification()),
    max :: integer(),
    corner :: etui@widgets@notification:corner()
}).
