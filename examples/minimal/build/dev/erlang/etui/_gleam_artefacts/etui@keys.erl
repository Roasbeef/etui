-module(etui@keys).
-compile([no_auto_import, nowarn_ignored, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-export([no_modifiers/0, is_plain/1, parse/1, match/1, is_char/1, char_value/1, is_navigation/1, is_modifier/1, pressed/2, pressed_with/3, ctrl/0, alt/0, shift/0, to_string/1]).
-export_type([key/0, modifiers/0, key_event/0]).

-type key() :: {char, binary()} | up | down | left | right | enter | backspace | delete | tab | back_tab | home | 'end' | page_up | page_down | escape | insert | {f, integer()} | {ctrl, binary()} | {alt, binary()} | {unknown, binary()}.

-type modifiers() :: {modifiers, boolean(), boolean(), boolean()}.

-type key_event() :: {key_event, key(), modifiers()}.

-file("src/etui/keys.gleam", 68).
-spec no_modifiers() -> modifiers().
-doc(~" No modifiers held.").
no_modifiers() ->
    {modifiers, false, false, false}.

-file("src/etui/keys.gleam", 73).
-spec is_plain(modifiers()) -> boolean().
-doc(~" True when nothing was held.").
is_plain(M) ->
    M =:= no_modifiers().

-file("src/etui/keys.gleam", 149).
-spec named_key(binary()) -> {ok, key()} | {error, nil}.
named_key(Raw) ->
    case Raw of
        ~"up" ->
            {ok, up};

        ~"down" ->
            {ok, down};

        ~"left" ->
            {ok, left};

        ~"right" ->
            {ok, right};

        ~"enter" ->
            {ok, enter};

        ~"backspace" ->
            {ok, backspace};

        ~"delete" ->
            {ok, delete};

        ~"tab" ->
            {ok, tab};

        ~"backtab" ->
            {ok, back_tab};

        ~"home" ->
            {ok, home};

        ~"end" ->
            {ok, 'end'};

        ~"pageup" ->
            {ok, page_up};

        ~"pagedown" ->
            {ok, page_down};

        ~"esc" ->
            {ok, escape};

        ~"insert" ->
            {ok, insert};

        ~"f1" ->
            {ok, {f, 1}};

        ~"f2" ->
            {ok, {f, 2}};

        ~"f3" ->
            {ok, {f, 3}};

        ~"f4" ->
            {ok, {f, 4}};

        ~"f5" ->
            {ok, {f, 5}};

        ~"f6" ->
            {ok, {f, 6}};

        ~"f7" ->
            {ok, {f, 7}};

        ~"f8" ->
            {ok, {f, 8}};

        ~"f9" ->
            {ok, {f, 9}};

        ~"f10" ->
            {ok, {f, 10}};

        ~"f11" ->
            {ok, {f, 11}};

        ~"f12" ->
            {ok, {f, 12}};

        _ ->
            {error, nil}
    end.

-file("src/etui/keys.gleam", 131).
-spec bare_key(binary()) -> key().
-doc(~" The key itself, with every modifier already removed.").
bare_key(Raw) ->
    case named_key(Raw) of
        {ok, Key} ->
            Key;

        {error, nil} ->
            case gleam@string:to_graphemes(Raw) of
                [_] ->
                    {char, Raw};

                _ ->
                    {unknown, Raw}
            end
    end.

-file("src/etui/keys.gleam", 121).
-spec strip_modifiers(binary(), modifiers()) -> {modifiers(), binary()}.
-doc(~" Peel `ctrl+`, `alt+` and `shift+` off the front, in any order.").
strip_modifiers(Raw, Acc) ->
    case Raw of
        <<"ctrl+"/utf8, Rest/binary>> ->
            strip_modifiers(Rest, {modifiers, true, erlang:element(3, Acc), erlang:element(4, Acc)});

        <<"alt+"/utf8, Rest@1/binary>> ->
            strip_modifiers(Rest@1, {modifiers, erlang:element(2, Acc), true, erlang:element(4, Acc)});

        <<"shift+"/utf8, Rest@2/binary>> ->
            strip_modifiers(Rest@2, {modifiers, erlang:element(2, Acc), erlang:element(3, Acc), true});

        _ ->
            {Acc, Raw}
    end.

-file("src/etui/keys.gleam", 111).
-spec parse(binary()) -> key_event().
-doc(~" Parse a raw key string (from `backend.KeyPress`) into a `Key`.

 Raw strings from the Erlang backend follow these conventions:
 - Printable ASCII/Unicode: the character itself (e.g. `\"a\"`, `\"A\"`, `\"€\"`)
 - Arrow keys: `\"up\"`, `\"down\"`, `\"left\"`, `\"right\"`
 - Control keys: `\"enter\"`, `\"backspace\"`, `\"delete\"`, `\"tab\"`, `\"backtab\"`,
   `\"home\"`, `\"end\"`, `\"pageup\"`, `\"pagedown\"`, `\"esc\"`, `\"insert\"`
 - Function keys: `\"f1\"` … `\"f12\"`
 - Ctrl combos: `\"ctrl+a\"` … `\"ctrl+z\"`, `\"ctrl+[\"`, etc.
 - Alt combos:  `\"alt+a\"` … `\"alt+z\"`, etc.
 Parse a raw key string into the key and the modifiers held with it.

 This is `match` with somewhere to put the modifiers. `match` answers
 `Ctrl(\"c\")` for a modified character and `Unknown` for a modified named
 key, because `Key` alone has no room for \"shift\" next to \"left\".").
parse(Raw) ->
    {Mods, Rest} = strip_modifiers(Raw, no_modifiers()),
    case Rest of
        ~"" ->
            {key_event, {unknown, Raw}, Mods};

        _ ->
            {key_event, bare_key(Rest), Mods}
    end.

-file("src/etui/keys.gleam", 184).
-spec match_modified(binary()) -> key().
match_modified(Raw) ->
    case parse(Raw) of
        {key_event, {char, C}, {modifiers, true, false, false}} ->
            {ctrl, C};

        {key_event, {char, C@1}, {modifiers, false, true, false}} ->
            {alt, C@1};

        {key_event, Code, Mods} ->
            case is_plain(Mods) of
                true ->
                    Code;

                false ->
                    {unknown, Raw}
            end
    end.

-file("src/etui/keys.gleam", 142).
-spec match(binary()) -> key().
match(Raw) ->
    case named_key(Raw) of
        {ok, Key} ->
            Key;

        {error, nil} ->
            match_modified(Raw)
    end.

-file("src/etui/keys.gleam", 203).
-spec is_char(key()) -> boolean().
-doc(~" True if key is a printable character (not a control/special key).").
is_char(K) ->
    case K of
        {char, _} ->
            true;

        _ ->
            false
    end.

-file("src/etui/keys.gleam", 211).
-spec char_value(key()) -> binary().
-doc(~" Extract the character string from a `Char` key. Returns `\"\"` for others.").
char_value(K) ->
    case K of
        {char, C} ->
            C;

        _ ->
            ~""
    end.

-file("src/etui/keys.gleam", 219).
-spec is_navigation(key()) -> boolean().
-doc(~" True if the key is a navigation key (arrows, home, end, page up/down).").
is_navigation(K) ->
    case K of
        up ->
            true;

        down ->
            true;

        left ->
            true;

        right ->
            true;

        home ->
            true;

        'end' ->
            true;

        page_up ->
            true;

        page_down ->
            true;

        _ ->
            false
    end.

-file("src/etui/keys.gleam", 227).
-spec is_modifier(key()) -> boolean().
-doc(~" True if the key is a modifier combo (Ctrl or Alt).").
is_modifier(K) ->
    case K of
        {ctrl, _} ->
            true;

        {alt, _} ->
            true;

        _ ->
            false
    end.

-file("src/etui/keys.gleam", 245).
-spec pressed(key_event(), key()) -> boolean().
-doc(~" True when `event` is exactly this key with nothing held.

 Named apart from `is_char` and friends on purpose: those ask what a `Key`
 is, this asks what happened.

 ```gleam
 keys.pressed(keys.parse(raw), keys.Left)   // \"left\" yes, \"shift+left\" no
 ```").
pressed(Event, Code) ->
    (erlang:element(2, Event) =:= Code) andalso is_plain(erlang:element(3, Event)).

-file("src/etui/keys.gleam", 250).
-spec pressed_with(key_event(), key(), modifiers()) -> boolean().
-doc(~" True when `event` is this key with exactly these modifiers.").
pressed_with(Event, Code, Mods) ->
    (erlang:element(2, Event) =:= Code) andalso (erlang:element(3, Event) =:= Mods).

-file("src/etui/keys.gleam", 255).
-spec ctrl() -> modifiers().
-doc(~" Just ctrl.").
ctrl() ->
    _record = no_modifiers(),
    {modifiers, true, erlang:element(3, _record), erlang:element(4, _record)}.

-file("src/etui/keys.gleam", 260).
-spec alt() -> modifiers().
-doc(~" Just alt.").
alt() ->
    _record = no_modifiers(),
    {modifiers, erlang:element(2, _record), true, erlang:element(4, _record)}.

-file("src/etui/keys.gleam", 265).
-spec shift() -> modifiers().
-doc(~" Just shift.").
shift() ->
    _record = no_modifiers(),
    {modifiers, erlang:element(2, _record), erlang:element(3, _record), true}.

-file("src/etui/keys.gleam", 295).
-spec code_name(key()) -> binary().
code_name(Code) ->
    case Code of
        {char, C} ->
            C;

        up ->
            ~"up";

        down ->
            ~"down";

        left ->
            ~"left";

        right ->
            ~"right";

        enter ->
            ~"enter";

        backspace ->
            ~"backspace";

        delete ->
            ~"delete";

        tab ->
            ~"tab";

        back_tab ->
            ~"backtab";

        home ->
            ~"home";

        'end' ->
            ~"end";

        page_up ->
            ~"pageup";

        page_down ->
            ~"pagedown";

        escape ->
            ~"esc";

        insert ->
            ~"insert";

        {f, N} ->
            <<"f"/utf8, (erlang:integer_to_binary(N))/binary>>;

        {ctrl, C@1} ->
            <<"ctrl+"/utf8, C@1/binary>>;

        {alt, C@2} ->
            <<"alt+"/utf8, C@2/binary>>;

        {unknown, Raw} ->
            Raw
    end.

-file("src/etui/keys.gleam", 279).
-spec prefix(modifiers()) -> binary().
prefix(M) ->
    Ctrl_part = case erlang:element(2, M) of
        true ->
            ~"ctrl+";

        false ->
            ~""
    end,
    Alt_part = case erlang:element(3, M) of
        true ->
            ~"alt+";

        false ->
            ~""
    end,
    Shift_part = case erlang:element(4, M) of
        true ->
            ~"shift+";

        false ->
            ~""
    end,
    <<<<Ctrl_part/binary, Alt_part/binary>>/binary, Shift_part/binary>>.

-file("src/etui/keys.gleam", 275).
-spec to_string(key_event()) -> binary().
-doc(~" The name a key event is delivered under, which is what `backend.KeyPress`
 carries and therefore what round-trips through `parse`.

 ```gleam
 keys.to_string(keys.KeyEvent(keys.Left, keys.shift()))  // \"shift+left\"
 ```").
to_string(Event) ->
    <<(prefix(erlang:element(3, Event)))/binary, (code_name(erlang:element(2, Event)))/binary>>.

