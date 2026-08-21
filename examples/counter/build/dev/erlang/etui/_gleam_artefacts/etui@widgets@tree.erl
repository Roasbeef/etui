-module(etui@widgets@tree).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([default_glyphs/0, ascii_glyphs/0, leaf/2, node/3, leaf_with_count/3, node_with_count/4, with_count/2, tree_new/1, with_glyphs/2, with_highlight_style/2, with_colors/3, with_style/2, state_new/0, state_from_tree/1, selected/1, is_expanded/2, expand/2, collapse/2, toggle_selected/2, select_next/2, select_prev/2, visible_row_count/2, effective_offset/3, render/4]).
-export_type([tree_node/0, tree_widget/0, tree_glyphs/0, tree_state/0, visible_row/0]).

-type tree_node() :: {tree_node, binary(), binary(), list(tree_node()), {ok, integer()} | {error, nil}}.

-type tree_widget() :: {tree_widget, list(tree_node()), etui@style:color(), etui@style:color(), etui@style:style(), tree_glyphs()}.

-type tree_glyphs() :: {tree_glyphs, binary(), binary(), binary(), binary()}.

-type tree_state() :: {tree_state, list(binary()), binary()}.

-type visible_row() :: {visible_row, binary(), integer(), binary(), boolean(), {ok, integer()} | {error, nil}}.

-file("src/etui/widgets/tree.gleam", 89).
-spec default_glyphs() -> tree_glyphs().
-doc(~" Default Unicode glyphs (▶ ▼ and box-drawing indent).").
default_glyphs() ->
    {tree_glyphs, ~"▶ ", ~"▼ ", ~"  ", ~"  "}.

-file("src/etui/widgets/tree.gleam", 94).
-spec ascii_glyphs() -> tree_glyphs().
-doc(~" ASCII-safe glyphs for terminals without Unicode support.").
ascii_glyphs() ->
    {tree_glyphs, ~"+ ", ~"- ", ~"  ", ~"  "}.

-file("src/etui/widgets/tree.gleam", 102).
-spec leaf(binary(), binary()) -> tree_node().
-doc(~" Create a leaf node (no children).").
leaf(Id, Label) ->
    {tree_node, Id, Label, [], {error, nil}}.

-file("src/etui/widgets/tree.gleam", 107).
-spec node(binary(), binary(), list(tree_node())) -> tree_node().
-doc(~" Create an internal node with children.").
node(Id, Label, Children) ->
    {tree_node, Id, Label, Children, {error, nil}}.

-file("src/etui/widgets/tree.gleam", 112).
-spec leaf_with_count(binary(), binary(), integer()) -> tree_node().
-doc(~" Leaf with a right-aligned count.").
leaf_with_count(Id, Label, Count) ->
    {tree_node, Id, Label, [], {ok, Count}}.

-file("src/etui/widgets/tree.gleam", 117).
-spec node_with_count(binary(), binary(), integer(), list(tree_node())) -> tree_node().
-doc(~" Internal node with a right-aligned count.").
node_with_count(Id, Label, Count, Children) ->
    {tree_node, Id, Label, Children, {ok, Count}}.

-file("src/etui/widgets/tree.gleam", 127).
-spec with_count(tree_node(), integer()) -> tree_node().
-doc(~" Attach a count to an existing node.").
with_count(N, Count) ->
    {tree_node, erlang:element(2, N), erlang:element(3, N), erlang:element(4, N), {ok, Count}}.

-file("src/etui/widgets/tree.gleam", 135).
-spec tree_new(list(tree_node())) -> tree_widget().
-doc(~" New tree widget. The first root node is selected initially.").
tree_new(Roots) ->
    {tree_widget, Roots, default, default, etui@style:new(default, default, etui@style:reverse()), default_glyphs()}.

-file("src/etui/widgets/tree.gleam", 145).
-spec with_glyphs(tree_widget(), tree_glyphs()) -> tree_widget().
with_glyphs(T, G) ->
    {tree_widget, erlang:element(2, T), erlang:element(3, T), erlang:element(4, T), erlang:element(5, T), G}.

-file("src/etui/widgets/tree.gleam", 149).
-spec with_highlight_style(tree_widget(), etui@style:style()) -> tree_widget().
with_highlight_style(T, S) ->
    {tree_widget, erlang:element(2, T), erlang:element(3, T), erlang:element(4, T), S, erlang:element(6, T)}.

-file("src/etui/widgets/tree.gleam", 153).
-spec with_colors(tree_widget(), etui@style:color(), etui@style:color()) -> tree_widget().
with_colors(T, Fg, Bg) ->
    {tree_widget, erlang:element(2, T), Fg, Bg, erlang:element(5, T), erlang:element(6, T)}.

-file("src/etui/widgets/tree.gleam", 161).
-spec with_style(tree_widget(), etui@style:style()) -> tree_widget().
with_style(T, S) ->
    {tree_widget, erlang:element(2, T), erlang:element(2, S), erlang:element(3, S), erlang:element(5, T), erlang:element(6, T)}.

-file("src/etui/widgets/tree.gleam", 169).
-spec state_new() -> tree_state().
-doc(~" Initial state: first root node selected, all nodes collapsed.").
state_new() ->
    {tree_state, [], ~""}.

-file("src/etui/widgets/tree.gleam", 174).
-spec state_from_tree(tree_widget()) -> tree_state().
-doc(~" Initial state with first root pre-selected.").
state_from_tree(T) ->
    First_id = case erlang:element(2, T) of
        [N | _] ->
            erlang:element(2, N);

        [] ->
            ~""
    end,
    {tree_state, [], First_id}.

-file("src/etui/widgets/tree.gleam", 186).
-spec selected(tree_state()) -> {ok, binary()} | {error, nil}.
-doc(~" ID of the currently selected node. `Error(Nil)` if nothing selected.").
selected(State) ->
    case erlang:element(3, State) of
        ~"" ->
            {error, nil};

        Id ->
            {ok, Id}
    end.

-file("src/etui/widgets/tree.gleam", 194).
-spec is_expanded(tree_state(), binary()) -> boolean().
-doc(~" `True` if the node with the given `id` is expanded.").
is_expanded(State, Id) ->
    gleam@list:contains(erlang:element(2, State), Id).

-file("src/etui/widgets/tree.gleam", 202).
-spec expand(binary(), tree_state()) -> tree_state().
-doc(~" Expand a node (show children).").
expand(Id, State) ->
    case gleam@list:contains(erlang:element(2, State), Id) of
        true ->
            State;

        false ->
            {tree_state, [Id | erlang:element(2, State)], erlang:element(3, State)}
    end.

-file("src/etui/widgets/tree.gleam", 210).
-spec collapse(binary(), tree_state()) -> tree_state().
-doc(~" Collapse a node (hide children).").
collapse(Id, State) ->
    {tree_state, gleam@list:filter(erlang:element(2, State), fun(E) ->
        E /= Id
    end), erlang:element(3, State)}.

-file("src/etui/widgets/tree.gleam", 400).
-spec node_has_children(list(tree_node()), binary()) -> boolean().
node_has_children(Nodes, Target_id) ->
    case Nodes of
        [] ->
            false;

        [N | Rest] ->
            case erlang:element(2, N) =:= Target_id of
                true ->
                    not gleam@list:is_empty(erlang:element(4, N));

                false ->
                    node_has_children(erlang:element(4, N), Target_id) orelse node_has_children(Rest, Target_id)
            end
    end.

-file("src/etui/widgets/tree.gleam", 215).
-spec toggle_selected(tree_state(), tree_widget()) -> tree_state().
-doc(~" Toggle expand/collapse on the currently selected node.").
toggle_selected(State, T) ->
    case erlang:element(3, State) of
        ~"" ->
            State;

        Id ->
            Has_children = node_has_children(erlang:element(2, T), Id),
            case Has_children of
                false ->
                    State;

                true ->
                    case is_expanded(State, Id) of
                        true ->
                            collapse(Id, State);

                        false ->
                            expand(Id, State)
                    end
            end
    end.

-file("src/etui/widgets/tree.gleam", 413).
-spec find_next(list(binary()), binary()) -> {ok, binary()} | {error, nil}.
find_next(Ids, Current) ->
    case Ids of
        [] ->
            {error, nil};

        [_] ->
            {error, nil};

        [H, Next | Rest] ->
            case H =:= Current of
                true ->
                    {ok, Next};

                false ->
                    find_next([Next | Rest], Current)
            end
    end.

-file("src/etui/widgets/tree.gleam", 306).
-spec flatten_visible(list(tree_node()), tree_state(), integer()) -> list(visible_row()).
flatten_visible(Nodes, State, Depth) ->
    gleam@list:flat_map(Nodes, fun(N) ->
        Has_ch = not gleam@list:is_empty(erlang:element(4, N)),
        Row = {visible_row, erlang:element(2, N), Depth, erlang:element(3, N), Has_ch, erlang:element(5, N)},
        Child_rows = case Has_ch andalso is_expanded(State, erlang:element(2, N)) of
            true ->
                flatten_visible(erlang:element(4, N), State, Depth + 1);

            false ->
                []
        end,
        [Row | Child_rows]
    end).

-file("src/etui/widgets/tree.gleam", 236).
-spec select_next(tree_state(), tree_widget()) -> tree_state().
-doc(~" Move selection to the next visible node.").
select_next(State, T) ->
    Visible = flatten_visible(erlang:element(2, T), State, 0),
    Ids = gleam@list:map(Visible, fun(Row) ->
        erlang:element(2, Row)
    end),
    case find_next(Ids, erlang:element(3, State)) of
        {ok, Next_id} ->
            {tree_state, erlang:element(2, State), Next_id};

        {error, _} ->
            State
    end.

-file("src/etui/widgets/tree.gleam", 429).
-spec find_prev_loop(list(binary()), binary(), {ok, binary()} | {error, nil}) -> {ok, binary()} | {error, nil}.
find_prev_loop(Ids, Current, Prev) ->
    case Ids of
        [] ->
            {error, nil};

        [H | Rest] ->
            case H =:= Current of
                true ->
                    Prev;

                false ->
                    find_prev_loop(Rest, Current, {ok, H})
            end
    end.

-file("src/etui/widgets/tree.gleam", 425).
-spec find_prev(list(binary()), binary()) -> {ok, binary()} | {error, nil}.
find_prev(Ids, Current) ->
    find_prev_loop(Ids, Current, {error, nil}).

-file("src/etui/widgets/tree.gleam", 246).
-spec select_prev(tree_state(), tree_widget()) -> tree_state().
-doc(~" Move selection to the previous visible node.").
select_prev(State, T) ->
    Visible = flatten_visible(erlang:element(2, T), State, 0),
    Ids = gleam@list:map(Visible, fun(Row) ->
        erlang:element(2, Row)
    end),
    case find_prev(Ids, erlang:element(3, State)) of
        {ok, Prev_id} ->
            {tree_state, erlang:element(2, State), Prev_id};

        {error, _} ->
            State
    end.

-file("src/etui/widgets/tree.gleam", 257).
-spec visible_row_count(tree_state(), tree_widget()) -> integer().
-doc(~" Number of visible rows (respects expand/collapse state).
 Use as `total` when building a scrollbar.").
visible_row_count(State, T) ->
    erlang:length(flatten_visible(erlang:element(2, T), State, 0)).

-file("src/etui/widgets/tree.gleam", 456).
-spec find_row_index(list(visible_row()), binary(), integer()) -> integer().
find_row_index(Rows, Id, Acc) ->
    case Rows of
        [] ->
            0;

        [R | Rest] ->
            case erlang:element(2, R) =:= Id of
                true ->
                    Acc;

                false ->
                    find_row_index(Rest, Id, Acc + 1)
            end
    end.

-file("src/etui/widgets/tree.gleam", 444).
-spec visible_scroll(list(visible_row()), binary(), integer()) -> integer().
visible_scroll(Rows, Selected, Height) ->
    Idx = find_row_index(Rows, Selected, 0),
    case Idx < Height of
        true ->
            0;

        false ->
            (Idx - Height) + 1
    end.

-file("src/etui/widgets/tree.gleam", 263).
-spec effective_offset(tree_state(), tree_widget(), integer()) -> integer().
-doc(~" Effective scroll offset for a viewport of `height` rows.
 Use as `offset` when building a scrollbar.").
effective_offset(State, T, Height) ->
    case Height =< 0 of
        true ->
            0;

        false ->
            Rows = flatten_visible(erlang:element(2, T), State, 0),
            visible_scroll(Rows, erlang:element(3, State), Height)
    end.

-file("src/etui/widgets/tree.gleam", 471).
-spec repeat_string_loop(binary(), integer(), binary()) -> binary().
repeat_string_loop(S, N, Acc) ->
    case N =< 0 of
        true ->
            Acc;

        false ->
            repeat_string_loop(S, N - 1, <<Acc/binary, S/binary>>)
    end.

-file("src/etui/widgets/tree.gleam", 467).
-spec repeat_string(binary(), integer()) -> binary().
repeat_string(S, N) ->
    repeat_string_loop(S, N, ~"").

-file("src/etui/widgets/tree.gleam", 329).
-spec render_rows(etui@buffer:buffer(), etui@geometry:rect(), tree_widget(), tree_state(), list(visible_row()), integer(), integer()) -> etui@buffer:buffer().
render_rows(Buf, Area, T, State, Rows, Scroll, Row_offset) ->
    case Row_offset >= erlang:element(3, erlang:element(3, Area)) of
        true ->
            Buf;

        false ->
            Visible_idx = Scroll + Row_offset,
            case gleam@list:drop(Rows, Visible_idx) of
                [] ->
                    Buf;

                [Row | _] ->
                    Y = erlang:element(3, erlang:element(2, Area)) + Row_offset,
                    Is_sel = erlang:element(2, Row) =:= erlang:element(3, State),
                    Prefix = <<(repeat_string(erlang:element(5, erlang:element(6, T)), erlang:element(3, Row)))/binary, (case erlang:element(5, Row) of
                        true ->
                            case is_expanded(State, erlang:element(2, Row)) of
                                true ->
                                    erlang:element(3, erlang:element(6, T));

                                false ->
                                    erlang:element(2, erlang:element(6, T))
                            end;

                        false ->
                            erlang:element(4, erlang:element(6, T))
                    end)/binary>>,
                    Count_str = case erlang:element(6, Row) of
                        {ok, N} ->
                            erlang:integer_to_binary(N);

                        {error, _} ->
                            ~""
                    end,
                    Count_w = etui@text:cell_width(Count_str),
                    Label_budget = case Count_w of
                        0 ->
                            erlang:element(2, erlang:element(3, Area));

                        _ ->
                            gleam@int:max(0, (erlang:element(2, erlang:element(3, Area)) - Count_w) - 1)
                    end,
                    Label_raw = <<Prefix/binary, (erlang:element(4, Row))/binary>>,
                    Label_part = etui@text:truncate(Label_raw, Label_budget, ~""),
                    Label_padded = etui@text:pad_right(Label_part, Label_budget),
                    Padded = case Count_w of
                        0 ->
                            etui@text:pad_right(Label_padded, erlang:element(2, erlang:element(3, Area)));

                        _ ->
                            <<<<Label_padded/binary, " "/utf8>>/binary, Count_str/binary>>
                    end,
                    Truncated = etui@text:truncate(Padded, erlang:element(2, erlang:element(3, Area)), ~""),
                    Padded@1 = etui@text:pad_right(Truncated, erlang:element(2, erlang:element(3, Area))),
                    {Fg, Bg, Modifier} = case Is_sel of
                        true ->
                            {erlang:element(2, erlang:element(5, T)), erlang:element(3, erlang:element(5, T)), erlang:element(4, erlang:element(5, T))};

                        false ->
                            {erlang:element(3, T), erlang:element(4, T), etui@style:none()}
                    end,
                    Buf2 = etui@buffer:set_string(Buf, {position, erlang:element(2, erlang:element(2, Area)), Y}, Padded@1, etui@style:new(Fg, Bg, Modifier)),
                    render_rows(Buf2, Area, T, State, Rows, Scroll, Row_offset + 1)
            end
    end.

-file("src/etui/widgets/tree.gleam", 277).
-spec render(etui@buffer:buffer(), etui@geometry:rect(), tree_widget(), tree_state()) -> etui@buffer:buffer().
-doc(~" Render the tree, scrolling so the selected node is visible.").
render(Buf, Area, T, State) ->
    case (erlang:element(3, erlang:element(3, Area)) =< 0) orelse (erlang:element(2, erlang:element(3, Area)) =< 0) of
        true ->
            Buf;

        false ->
            Rows = flatten_visible(erlang:element(2, T), State, 0),
            Scroll = visible_scroll(Rows, erlang:element(3, State), erlang:element(3, erlang:element(3, Area))),
            render_rows(Buf, Area, T, State, Rows, Scroll, 0)
    end.

