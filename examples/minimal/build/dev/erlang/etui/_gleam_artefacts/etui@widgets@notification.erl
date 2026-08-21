-module(etui@widgets@notification).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([queue_new/1, with_corner/2, info/2, success/2, warning/2, error/2, persistent/2, push/2, tick/1, dismiss_level/2, dismiss_all/1, dismiss_first/1, has_notifications/1, count/1, render/3]).
-export_type([level/0, notification/0, notification_queue/0, corner/0]).

-type level() :: info | success | warning | error.

-type notification() :: {notification, binary(), level(), integer()}.

-type notification_queue() :: {notification_queue, list(notification()), integer(), corner()}.

-type corner() :: top_right | top_left | bottom_right | bottom_left.

-file("src/etui/widgets/notification.gleam", 72).
-spec queue_new(integer()) -> notification_queue().
-doc(~" New empty queue. Max = 5, corner = BottomRight.").
queue_new(Max) ->
    {notification_queue, [], Max, bottom_right}.

-file("src/etui/widgets/notification.gleam", 77).
-spec with_corner(notification_queue(), corner()) -> notification_queue().
-doc(~" Set which corner to stack notifications.").
with_corner(Q, Corner) ->
    {notification_queue, erlang:element(2, Q), erlang:element(3, Q), Corner}.

-file("src/etui/widgets/notification.gleam", 82).
-spec info(binary(), integer()) -> notification().
-doc(~" Build an Info notification.").
info(Message, Ttl) ->
    {notification, Message, info, Ttl}.

-file("src/etui/widgets/notification.gleam", 87).
-spec success(binary(), integer()) -> notification().
-doc(~" Build a Success notification.").
success(Message, Ttl) ->
    {notification, Message, success, Ttl}.

-file("src/etui/widgets/notification.gleam", 92).
-spec warning(binary(), integer()) -> notification().
-doc(~" Build a Warning notification.").
warning(Message, Ttl) ->
    {notification, Message, warning, Ttl}.

-file("src/etui/widgets/notification.gleam", 97).
-spec error(binary(), integer()) -> notification().
-doc(~" Build an Error notification (persistent by default: ttl = -1).").
error(Message, Ttl) ->
    {notification, Message, error, Ttl}.

-file("src/etui/widgets/notification.gleam", 102).
-spec persistent(binary(), level()) -> notification().
-doc(~" Persistent notification (never auto-expires; dismiss manually).").
persistent(Message, Level) ->
    {notification, Message, Level, -1}.

-file("src/etui/widgets/notification.gleam", 110).
-spec push(notification_queue(), notification()) -> notification_queue().
-doc(~" Add a notification. If queue is full, the oldest is dropped.").
push(Q, N) ->
    Items = lists:append(erlang:element(2, Q), [N]),
    Trimmed = case erlang:length(Items) > erlang:element(3, Q) of
        true ->
            gleam@list:drop(Items, erlang:length(Items) - erlang:element(3, Q));

        false ->
            Items
    end,
    {notification_queue, Trimmed, erlang:element(3, Q), erlang:element(4, Q)}.

-file("src/etui/widgets/notification.gleam", 121).
-spec tick(notification_queue()) -> notification_queue().
-doc(~" Advance time by one tick. Decrements TTL on all non-persistent
 notifications and removes expired ones (ttl == 0).").
tick(Q) ->
    Items = begin
        _pipe = erlang:element(2, Q),
        _pipe@1 = gleam@list:map(_pipe, fun(N) ->
            case erlang:element(4, N) of
                -1 ->
                    N;

                T ->
                    {notification, erlang:element(2, N), erlang:element(3, N), T - 1}
            end
        end),
        gleam@list:filter(_pipe@1, fun(N) ->
            erlang:element(4, N) /= 0
        end)
    end,
    {notification_queue, Items, erlang:element(3, Q), erlang:element(4, Q)}.

-file("src/etui/widgets/notification.gleam", 135).
-spec dismiss_level(notification_queue(), level()) -> notification_queue().
-doc(~" Dismiss all notifications matching `level`.").
dismiss_level(Q, Level) ->
    {notification_queue, gleam@list:filter(erlang:element(2, Q), fun(N) ->
        erlang:element(3, N) /= Level
    end), erlang:element(3, Q), erlang:element(4, Q)}.

-file("src/etui/widgets/notification.gleam", 143).
-spec dismiss_all(notification_queue()) -> notification_queue().
-doc(~" Dismiss all notifications.").
dismiss_all(Q) ->
    {notification_queue, [], erlang:element(3, Q), erlang:element(4, Q)}.

-file("src/etui/widgets/notification.gleam", 148).
-spec dismiss_first(notification_queue()) -> notification_queue().
-doc(~" Dismiss the oldest notification.").
dismiss_first(Q) ->
    case erlang:element(2, Q) of
        [] ->
            Q;

        [_ | Rest] ->
            {notification_queue, Rest, erlang:element(3, Q), erlang:element(4, Q)}
    end.

-file("src/etui/widgets/notification.gleam", 156).
-spec has_notifications(notification_queue()) -> boolean().
-doc(~" True if there are active notifications.").
has_notifications(Q) ->
    not gleam@list:is_empty(erlang:element(2, Q)).

-file("src/etui/widgets/notification.gleam", 161).
-spec count(notification_queue()) -> integer().
-doc(~" Count of active notifications.").
count(Q) ->
    erlang:length(erlang:element(2, Q)).

-file("src/etui/widgets/notification.gleam", 262).
-spec level_colors(level()) -> {etui@style:color(), etui@style:color()}.
level_colors(Level) ->
    case Level of
        info ->
            {{indexed, 15}, {indexed, 4}};

        success ->
            {{indexed, 15}, {indexed, 2}};

        warning ->
            {{indexed, 0}, {indexed, 3}};

        error ->
            {{indexed, 15}, {indexed, 1}}
    end.

-file("src/etui/widgets/notification.gleam", 181).
-spec render_items(etui@buffer:buffer(), etui@geometry:rect(), list(notification()), corner(), integer()) -> etui@buffer:buffer().
render_items(Buf, Area, Items, Corner, Index) ->
    case Items of
        [] ->
            Buf;

        [N | Rest] ->
            Box_h = 3,
            Msg_w = etui@text:cell_width(erlang:element(2, N)),
            Box_w = case (Msg_w + 4) > 30 of
                true ->
                    case (Msg_w + 4) > erlang:element(2, erlang:element(3, Area)) of
                        true ->
                            erlang:element(2, erlang:element(3, Area));

                        false ->
                            Msg_w + 4
                    end;

                false ->
                    30
            end,
            {X, Y} = case Corner of
                top_right ->
                    {(erlang:element(2, erlang:element(2, Area)) + erlang:element(2, erlang:element(3, Area))) - Box_w, erlang:element(3, erlang:element(2, Area)) + (Index * Box_h)};

                top_left ->
                    {erlang:element(2, erlang:element(2, Area)), erlang:element(3, erlang:element(2, Area)) + (Index * Box_h)};

                bottom_right ->
                    {(erlang:element(2, erlang:element(2, Area)) + erlang:element(2, erlang:element(3, Area))) - Box_w, ((erlang:element(3, erlang:element(2, Area)) + erlang:element(3, erlang:element(3, Area))) - Box_h) - (Index * Box_h)};

                bottom_left ->
                    {erlang:element(2, erlang:element(2, Area)), ((erlang:element(3, erlang:element(2, Area)) + erlang:element(3, erlang:element(3, Area))) - Box_h) - (Index * Box_h)}
            end,
            Fits = (((X >= erlang:element(2, erlang:element(2, Area))) andalso (Y >= erlang:element(3, erlang:element(2, Area)))) andalso ((X + Box_w) =< (erlang:element(2, erlang:element(2, Area)) + erlang:element(2, erlang:element(3, Area))))) andalso ((Y + Box_h) =< (erlang:element(3, erlang:element(2, Area)) + erlang:element(3, erlang:element(3, Area)))),
            Buf2 = case Fits of
                false ->
                    Buf;

                true ->
                    Box_area = {rect, {position, X, Y}, {size, Box_w, Box_h}},
                    {Fg, Bg} = level_colors(erlang:element(3, N)),
                    Blk = begin
                        _pipe = etui@widgets@block:block_new(),
                        _pipe@1 = etui@widgets@block:with_border(_pipe, rounded),
                        _pipe@2 = etui@widgets@block:with_style(_pipe@1, Fg, Bg),
                        etui@widgets@block:with_bg_fill(_pipe@2)
                    end,
                    Buf_b = etui@widgets@block:render(Buf, Box_area, Blk),
                    Inner = etui@widgets@block:inner(Box_area, Blk),
                    Msg_x = erlang:element(2, erlang:element(2, Inner)) + ((erlang:element(2, erlang:element(3, Inner)) - etui@text:cell_width(erlang:element(2, N))) div 2),
                    case (erlang:element(2, erlang:element(3, Inner)) > 0) andalso (erlang:element(3, erlang:element(3, Inner)) > 0) of
                        false ->
                            Buf_b;

                        true ->
                            etui@buffer:set_string(Buf_b, {position, Msg_x, erlang:element(3, erlang:element(2, Inner))}, etui@text:truncate(erlang:element(2, N), erlang:element(2, erlang:element(3, Inner)), ~"…"), etui@style:new(Fg, Bg, etui@style:none()))
                    end
            end,
            render_items(Buf2, Area, Rest, Corner, Index + 1)
    end.

-file("src/etui/widgets/notification.gleam", 170).
-spec render(etui@buffer:buffer(), etui@geometry:rect(), notification_queue()) -> etui@buffer:buffer().
-doc(~" Render all active notifications stacked in the configured corner.
 Each notification is a single-row bordered box; they stack inward.").
render(Buf, Area, Q) ->
    case (gleam@list:is_empty(erlang:element(2, Q)) orelse (erlang:element(2, erlang:element(3, Area)) =< 0)) orelse (erlang:element(3, erlang:element(3, Area)) =< 0) of
        true ->
            Buf;

        false ->
            render_items(Buf, Area, erlang:element(2, Q), erlang:element(4, Q), 0)
    end.

