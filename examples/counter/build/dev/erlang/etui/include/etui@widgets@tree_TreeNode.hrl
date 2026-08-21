-record(tree_node, {
    id :: binary(),
    label :: binary(),
    children :: list(etui@widgets@tree:tree_node()),
    count :: {ok, integer()} | {error, nil}
}).
