/// Named key constants and pattern-match helper for keyboard events.
///
/// Instead of comparing raw strings from `backend.KeyPress(key)` everywhere,
/// use these constants for clarity and to avoid typos.
///
/// ```gleam
/// import etui/keys
/// import etui/backend
///
/// fn on_event(ev: backend.InputEvent, state: Model) -> Model {
///   case ev {
///     backend.KeyPress(k) -> case keys.match(k) {
///       keys.Up    -> Model(..state, selected: state.selected - 1)
///       keys.Down  -> Model(..state, selected: state.selected + 1)
///       keys.Enter -> Model(..state, open: True)
///       keys.Char(c) -> handle_char(c, state)
///       _          -> state
///     }
///     _ -> state
///   }
/// }
/// ```
import gleam/int
import gleam/string

// ─────────────────────────────────────────────────────────────────
// Key type

pub type Key {
  /// Plain printable character (single grapheme, not a control key).
  Char(String)
  Up
  Down
  Left
  Right
  Enter
  Backspace
  Delete
  Tab
  BackTab
  Home
  End
  PageUp
  PageDown
  Escape
  Insert
  /// F1–F12
  F(Int)
  /// Ctrl+<char>, e.g. Ctrl("c"), Ctrl("d").
  ///
  /// Only for a modifier held with a *character*. A modifier held with a
  /// named key is a `KeyEvent`: `Ctrl("right")` would say that ctrl and the
  /// character "right" were pressed, which is five characters and not what
  /// happened.
  Ctrl(String)
  /// Alt+<char>, e.g. Alt("f"). Same restriction as `Ctrl`.
  Alt(String)
  /// Unknown / unrecognised key string.
  Unknown(String)
}

/// Which modifiers were held down.
pub type Modifiers {
  Modifiers(ctrl: Bool, alt: Bool, shift: Bool)
}

/// No modifiers held.
pub fn no_modifiers() -> Modifiers {
  Modifiers(ctrl: False, alt: False, shift: False)
}

/// True when nothing was held.
pub fn is_plain(m: Modifiers) -> Bool {
  m == no_modifiers()
}

/// A key press: what was pressed, and what was held with it.
///
/// `match` cannot express `shift+left`, because `Key` has nowhere to put the
/// shift. `parse` can:
///
/// ```gleam
/// case keys.parse(raw) {
///   keys.KeyEvent(keys.Left, keys.Modifiers(shift: True, ..)) -> select_left()
///   keys.KeyEvent(keys.Left, _) -> move_left()
///   _ -> model
/// }
/// ```
pub type KeyEvent {
  KeyEvent(code: Key, modifiers: Modifiers)
}

// ─────────────────────────────────────────────────────────────────
// Match helper

/// Parse a raw key string (from `backend.KeyPress`) into a `Key`.
///
/// Raw strings from the Erlang backend follow these conventions:
/// - Printable ASCII/Unicode: the character itself (e.g. `"a"`, `"A"`, `"€"`)
/// - Arrow keys: `"up"`, `"down"`, `"left"`, `"right"`
/// - Control keys: `"enter"`, `"backspace"`, `"delete"`, `"tab"`, `"backtab"`,
///   `"home"`, `"end"`, `"pageup"`, `"pagedown"`, `"esc"`, `"insert"`
/// - Function keys: `"f1"` … `"f12"`
/// - Ctrl combos: `"ctrl+a"` … `"ctrl+z"`, `"ctrl+["`, etc.
/// - Alt combos:  `"alt+a"` … `"alt+z"`, etc.
/// Parse a raw key string into the key and the modifiers held with it.
///
/// This is `match` with somewhere to put the modifiers. `match` answers
/// `Ctrl("c")` for a modified character and `Unknown` for a modified named
/// key, because `Key` alone has no room for "shift" next to "left".
pub fn parse(raw: String) -> KeyEvent {
  let #(mods, rest) = strip_modifiers(raw, no_modifiers())
  case rest {
    // A bare modifier prefix with nothing after it is not a key press.
    "" -> KeyEvent(code: Unknown(raw), modifiers: mods)
    _ -> KeyEvent(code: bare_key(rest), modifiers: mods)
  }
}

/// Peel `ctrl+`, `alt+` and `shift+` off the front, in any order.
fn strip_modifiers(raw: String, acc: Modifiers) -> #(Modifiers, String) {
  case raw {
    "ctrl+" <> rest -> strip_modifiers(rest, Modifiers(..acc, ctrl: True))
    "alt+" <> rest -> strip_modifiers(rest, Modifiers(..acc, alt: True))
    "shift+" <> rest -> strip_modifiers(rest, Modifiers(..acc, shift: True))
    _ -> #(acc, raw)
  }
}

/// The key itself, with every modifier already removed.
fn bare_key(raw: String) -> Key {
  case named_key(raw) {
    Ok(key) -> key
    Error(Nil) ->
      case string.to_graphemes(raw) {
        [_] -> Char(raw)
        _ -> Unknown(raw)
      }
  }
}

pub fn match(raw: String) -> Key {
  case named_key(raw) {
    Ok(key) -> key
    Error(Nil) -> match_modified(raw)
  }
}

fn named_key(raw: String) -> Result(Key, Nil) {
  case raw {
    "up" -> Ok(Up)
    "down" -> Ok(Down)
    "left" -> Ok(Left)
    "right" -> Ok(Right)
    "enter" -> Ok(Enter)
    "backspace" -> Ok(Backspace)
    "delete" -> Ok(Delete)
    "tab" -> Ok(Tab)
    "backtab" -> Ok(BackTab)
    "home" -> Ok(Home)
    "end" -> Ok(End)
    "pageup" -> Ok(PageUp)
    "pagedown" -> Ok(PageDown)
    "esc" -> Ok(Escape)
    "insert" -> Ok(Insert)
    "f1" -> Ok(F(1))
    "f2" -> Ok(F(2))
    "f3" -> Ok(F(3))
    "f4" -> Ok(F(4))
    "f5" -> Ok(F(5))
    "f6" -> Ok(F(6))
    "f7" -> Ok(F(7))
    "f8" -> Ok(F(8))
    "f9" -> Ok(F(9))
    "f10" -> Ok(F(10))
    "f11" -> Ok(F(11))
    "f12" -> Ok(F(12))
    _ -> Error(Nil)
  }
}

// What `match` can still say about a key that carries modifiers: a single
// character with ctrl or alt, and nothing else. Anything richer needs `parse`.
fn match_modified(raw: String) -> Key {
  case parse(raw) {
    KeyEvent(Char(c), Modifiers(ctrl: True, alt: False, shift: False)) ->
      Ctrl(c)
    KeyEvent(Char(c), Modifiers(ctrl: False, alt: True, shift: False)) -> Alt(c)
    KeyEvent(code, mods) ->
      case is_plain(mods) {
        True -> code
        // "shift+left" has no Key of its own, and calling it Char would hand a
        // widget a ten-grapheme "character" to insert into a text field.
        False -> Unknown(raw)
      }
  }
}

// ─────────────────────────────────────────────────────────────────
// Convenience predicates

/// True if key is a printable character (not a control/special key).
pub fn is_char(k: Key) -> Bool {
  case k {
    Char(_) -> True
    _ -> False
  }
}

/// Extract the character string from a `Char` key. Returns `""` for others.
pub fn char_value(k: Key) -> String {
  case k {
    Char(c) -> c
    _ -> ""
  }
}

/// True if the key is a navigation key (arrows, home, end, page up/down).
pub fn is_navigation(k: Key) -> Bool {
  case k {
    Up | Down | Left | Right | Home | End | PageUp | PageDown -> True
    _ -> False
  }
}

/// True if the key is a modifier combo (Ctrl or Alt).
pub fn is_modifier(k: Key) -> Bool {
  case k {
    Ctrl(_) | Alt(_) -> True
    _ -> False
  }
}

// ─────────────────────────────────────────────────────────────────
// Reading a KeyEvent

/// True when `event` is exactly this key with nothing held.
///
/// Named apart from `is_char` and friends on purpose: those ask what a `Key`
/// is, this asks what happened.
///
/// ```gleam
/// keys.pressed(keys.parse(raw), keys.Left)   // "left" yes, "shift+left" no
/// ```
pub fn pressed(event: KeyEvent, code: Key) -> Bool {
  event.code == code && is_plain(event.modifiers)
}

/// True when `event` is this key with exactly these modifiers.
pub fn pressed_with(event: KeyEvent, code: Key, mods: Modifiers) -> Bool {
  event.code == code && event.modifiers == mods
}

/// Just ctrl.
pub fn ctrl() -> Modifiers {
  Modifiers(..no_modifiers(), ctrl: True)
}

/// Just alt.
pub fn alt() -> Modifiers {
  Modifiers(..no_modifiers(), alt: True)
}

/// Just shift.
pub fn shift() -> Modifiers {
  Modifiers(..no_modifiers(), shift: True)
}

/// The name a key event is delivered under, which is what `backend.KeyPress`
/// carries and therefore what round-trips through `parse`.
///
/// ```gleam
/// keys.to_string(keys.KeyEvent(keys.Left, keys.shift()))  // "shift+left"
/// ```
pub fn to_string(event: KeyEvent) -> String {
  prefix(event.modifiers) <> code_name(event.code)
}

fn prefix(m: Modifiers) -> String {
  let ctrl_part = case m.ctrl {
    True -> "ctrl+"
    False -> ""
  }
  let alt_part = case m.alt {
    True -> "alt+"
    False -> ""
  }
  let shift_part = case m.shift {
    True -> "shift+"
    False -> ""
  }
  ctrl_part <> alt_part <> shift_part
}

fn code_name(code: Key) -> String {
  case code {
    Char(c) -> c
    Up -> "up"
    Down -> "down"
    Left -> "left"
    Right -> "right"
    Enter -> "enter"
    Backspace -> "backspace"
    Delete -> "delete"
    Tab -> "tab"
    BackTab -> "backtab"
    Home -> "home"
    End -> "end"
    PageUp -> "pageup"
    PageDown -> "pagedown"
    Escape -> "esc"
    Insert -> "insert"
    F(n) -> "f" <> int.to_string(n)
    Ctrl(c) -> "ctrl+" <> c
    Alt(c) -> "alt+" <> c
    Unknown(raw) -> raw
  }
}
