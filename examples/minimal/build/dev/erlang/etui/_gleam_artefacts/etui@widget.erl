-module(etui@widget).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([render_stateful/4, freeze/2, freeze_frame/2, layer/2, at/2, compose/3, stack/1, empty/0]).
-export_type([stateful_widget/1]).

-type stateful_widget(EPN) :: {stateful_widget, fun((etui@buffer:buffer(), etui@geometry:rect(), EPN) -> etui@buffer:buffer())}.

-file("src/etui/widget.gleam", 102).
-spec render_stateful(etui@buffer:buffer(), etui@geometry:rect(), stateful_widget(EPO), EPO) -> etui@buffer:buffer().
-doc(~" Render a stateful widget with the given state value.").
render_stateful(Buf, Area, W, State) ->
    (erlang:element(2, W))(Buf, Area, State).

-file("src/etui/widget.gleam", 113).
-spec freeze(stateful_widget(EPQ), EPQ) -> fun((etui@buffer:buffer(), etui@geometry:rect()) -> etui@buffer:buffer()).
-doc(~" Bake state into a stateless Widget.
 The resulting Widget ignores any state updates after this call.").
freeze(W, State) ->
    fun(Buf, Area) ->
        (erlang:element(2, W))(Buf, Area, State)
    end.

-file("src/etui/widget.gleam", 121).
-spec freeze_frame(fun((etui@buffer:buffer(), etui@geometry:rect(), integer()) -> etui@buffer:buffer()), integer()) -> fun((etui@buffer:buffer(), etui@geometry:rect()) -> etui@buffer:buffer()).
-doc(~" Bind a frame number to an AnimatedWidget, producing a stateless Widget.").
freeze_frame(W, Frame) ->
    fun(Buf, Area) ->
        W(Buf, Area, Frame)
    end.

-file("src/etui/widget.gleam", 130).
-spec layer(fun((etui@buffer:buffer(), etui@geometry:rect()) -> etui@buffer:buffer()), fun((etui@buffer:buffer(), etui@geometry:rect()) -> etui@buffer:buffer())) -> fun((etui@buffer:buffer(), etui@geometry:rect()) -> etui@buffer:buffer()).
-doc(~" Draw two widgets in the same area: `bottom` first, then `top` on top.
 Use for overlaying a popup, cursor, or status indicator over content.").
layer(Bottom, Top) ->
    fun(Buf, Area) ->
        _pipe = Buf,
        _pipe@1 = Bottom(_pipe, Area),
        Top(_pipe@1, Area)
    end.

-file("src/etui/widget.gleam", 136).
-spec at(fun((etui@buffer:buffer(), etui@geometry:rect()) -> etui@buffer:buffer()), etui@geometry:rect()) -> fun((etui@buffer:buffer(), etui@geometry:rect()) -> etui@buffer:buffer()).
-doc(~" Pin a widget to a fixed `sub_area`, ignoring the caller-supplied area.
 Use when a widget's position is pre-computed and shouldn't be overridden.").
at(W, Sub_area) ->
    fun(Buf, _) ->
        W(Buf, Sub_area)
    end.

-file("src/etui/widget.gleam", 153).
-spec compose(fun((etui@buffer:buffer(), etui@geometry:rect()) -> etui@buffer:buffer()), etui@geometry:rect(), fun((etui@buffer:buffer(), etui@geometry:rect()) -> etui@buffer:buffer())) -> fun((etui@buffer:buffer(), etui@geometry:rect()) -> etui@buffer:buffer()).
-doc(~" Render `border_w` over `area`, then `content_w` over `inner_area`.
 Convenience for the common \"block border + child content\" pattern:

 ```gleam
 let blk = block.block_new() |> block.with_border(block.Single)
 let inner = block.inner(area, blk)
 let composed = widget.compose(
   fn(buf, a) { block.render(buf, a, blk) },
   inner,
   fn(buf, a) { paragraph.render(buf, a, para) },
 )
 composed(buf, area)
 ```").
compose(Border_w, Inner_area, Content_w) ->
    fun(Buf, Area) ->
        _pipe = Buf,
        _pipe@1 = Border_w(_pipe, Area),
        Content_w(_pipe@1, Inner_area)
    end.

-file("src/etui/widget.gleam", 166).
-spec fold_widgets(etui@buffer:buffer(), etui@geometry:rect(), list(fun((etui@buffer:buffer(), etui@geometry:rect()) -> etui@buffer:buffer()))) -> etui@buffer:buffer().
fold_widgets(Buf, Area, Widgets) ->
    case Widgets of
        [] ->
            Buf;

        [W | Rest] ->
            fold_widgets(W(Buf, Area), Area, Rest)
    end.

-file("src/etui/widget.gleam", 162).
-spec stack(list(fun((etui@buffer:buffer(), etui@geometry:rect()) -> etui@buffer:buffer()))) -> fun((etui@buffer:buffer(), etui@geometry:rect()) -> etui@buffer:buffer()).
-doc(~" Apply a list of widgets to the same area in order (each draws on top of the previous).").
stack(Widgets) ->
    fun(Buf, Area) ->
        fold_widgets(Buf, Area, Widgets)
    end.

-file("src/etui/widget.gleam", 181).
-spec empty() -> fun((etui@buffer:buffer(), etui@geometry:rect()) -> etui@buffer:buffer()).
-doc(~" A widget that renders nothing. Useful as a default or placeholder.").
empty() ->
    fun(Buf, _) ->
        Buf
    end.

