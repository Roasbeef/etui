-record(tree_widget, {
    roots :: list(etui@widgets@tree:tree_node()),
    fg :: etui@style:color(),
    bg :: etui@style:color(),
    highlight_style :: etui@style:style(),
    glyphs :: etui@widgets@tree:tree_glyphs()
}).
