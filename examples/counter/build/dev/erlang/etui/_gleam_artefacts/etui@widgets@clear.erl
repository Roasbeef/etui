-module(etui@widgets@clear).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([render/2]).

-file("src/etui/widgets/clear.gleam", 15).
-spec render(etui@buffer:buffer(), etui@geometry:rect()) -> etui@buffer:buffer().
-doc(~" Fill `area` with empty cells (space, Default colors, no modifier).").
render(Buf, Area) ->
    etui@buffer:clear(Buf, Area).

