-record(undo_stack, {
    past :: list(any()),
    present :: any(),
    future :: list(any()),
    max_size :: integer()
}).
