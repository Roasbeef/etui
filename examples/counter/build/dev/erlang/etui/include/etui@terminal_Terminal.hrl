-record(terminal, {
    backend :: etui@backend:backend(any()),
    state :: any(),
    viewport :: etui@terminal:viewport(),
    previous :: etui@buffer:buffer(),
    repaint :: boolean()
}).
