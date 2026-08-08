/// Terminal input parsing: raw bytes to `InputEvent`s.
///
/// This module is pure. It knows nothing about terminals, timeouts or I/O, so
/// every sequence below is testable without a TTY.
///
/// ## Why incremental
///
/// A read from the terminal returns whatever bytes happen to be buffered. That
/// might be half of an escape sequence, or six key presses that arrived while
/// the previous frame was rendering. Treating one read as one key press loses
/// everything but the first, which is what happens when you type fast or paste.
///
/// `parse` therefore returns *all* the events it can decode plus the bytes it
/// could not yet make sense of:
///
/// ```gleam
/// let input.Parsed(events, remainder) = input.parse(pending <> chunk)
/// ```
///
/// Keep `remainder` and prepend it to the next read. When a read times out with
/// a remainder still pending, hand it to `flush`: the only sequence that stays
/// incomplete in practice is a lone ESC, which means the user pressed Escape.
///
/// ## Key names
///
/// Keys are named strings so they can be matched with `etui/keys`:
/// `"a"`, `"enter"`, `"up"`, `"f5"`, `"ctrl+c"`, `"alt+x"`, `"ctrl+shift+left"`.
/// Modifier order is always `ctrl+alt+shift+`.
import etui/backend.{
  type InputEvent, KeyPress, MouseDrag, MouseLeft, MouseMiddle, MouseMove,
  MousePress, MouseRelease, MouseRight, MouseScroll, Paste,
}
import gleam/int
import gleam/list
import gleam/result
import gleam/string

const esc = "\u{001B}"

/// Events decoded from a chunk, plus the bytes that did not form a complete
/// sequence. `remainder` is always either empty or starts with ESC.
pub type Parsed {
  Parsed(events: List(InputEvent), remainder: String)
}

/// Decode as many events as possible from `chunk`.
///
/// ```gleam
/// input.parse("ab")                  // two KeyPress events
/// input.parse("\u{001B}[A")          // KeyPress("up")
/// input.parse("\u{001B}[")           // no events, remainder "\u{001B}["
/// ```
pub fn parse(chunk: String) -> Parsed {
  let #(rev_events, remainder) = parse_loop(string.to_graphemes(chunk), [])
  Parsed(events: list.reverse(rev_events), remainder: string.concat(remainder))
}

/// Turn a leftover remainder into events once it is clear no more input is
/// coming (the read timed out).
///
/// A remainder always starts with ESC. If that is all it is, the user pressed
/// Escape. A genuinely truncated sequence also yields Escape; its trailing
/// bytes are dropped rather than delivered as stray key presses, because a
/// half escape sequence is not text the user typed.
pub fn flush(remainder: String) -> List(InputEvent) {
  case remainder {
    "" -> []
    _ -> [KeyPress("esc")]
  }
}

// ─────────────────────────────────────────────────────────────────
// Main loop

fn parse_loop(
  gs: List(String),
  rev: List(InputEvent),
) -> #(List(InputEvent), List(String)) {
  case gs {
    [] -> #(rev, [])
    [g, ..rest] ->
      case g == esc {
        False -> parse_loop(rest, [KeyPress(simple_key(g)), ..rev])
        True ->
          case parse_esc(rest) {
            Ok(#(event, remaining)) -> parse_loop(remaining, [event, ..rev])
            // Incomplete: hand back everything from the ESC onwards so the
            // caller can prepend it to the next read.
            Error(Nil) -> #(rev, gs)
          }
      }
  }
}

// ─────────────────────────────────────────────────────────────────
// Escape sequences

fn parse_esc(rest: List(String)) -> Result(#(InputEvent, List(String)), Nil) {
  case rest {
    [] -> Error(Nil)
    ["[", ..after] -> parse_csi(after)
    ["O", ..after] -> parse_ss3(after)
    // ESC followed by a printable character is Alt+that character.
    [c, ..after] -> Ok(#(KeyPress("alt+" <> c), after))
  }
}

// SS3: ESC O <char>. Emitted by some terminals for arrows and F1-F4.
fn parse_ss3(after: List(String)) -> Result(#(InputEvent, List(String)), Nil) {
  case after {
    [] -> Error(Nil)
    [c, ..rest] -> Ok(#(KeyPress(ss3_key(c)), rest))
  }
}

fn ss3_key(c: String) -> String {
  case c {
    "A" -> "up"
    "B" -> "down"
    "C" -> "right"
    "D" -> "left"
    "H" -> "home"
    "F" -> "end"
    "P" -> "f1"
    "Q" -> "f2"
    "R" -> "f3"
    "S" -> "f4"
    other -> other
  }
}

fn parse_csi(after: List(String)) -> Result(#(InputEvent, List(String)), Nil) {
  case after {
    ["<", ..body] -> parse_sgr_mouse(body)
    _ -> {
      use #(params, final, rest) <- result.try(collect_csi(after, []))
      case params, final {
        "200", "~" -> parse_paste(rest, [])
        _, _ -> Ok(#(KeyPress(csi_key(params, final)), rest))
      }
    }
  }
}

// A CSI sequence ends at the first byte in 0x40..0x7E. Everything before it is
// parameter text (digits, ';', and private markers).
fn collect_csi(
  gs: List(String),
  rev_params: List(String),
) -> Result(#(String, String, List(String)), Nil) {
  case gs {
    [] -> Error(Nil)
    [g, ..rest] ->
      case is_final_byte(g) {
        True -> Ok(#(string.concat(list.reverse(rev_params)), g, rest))
        False -> collect_csi(rest, [g, ..rev_params])
      }
  }
}

fn is_final_byte(g: String) -> Bool {
  case string.to_utf_codepoints(g) {
    [cp, ..] -> {
      let n = string.utf_codepoint_to_int(cp)
      n >= 0x40 && n <= 0x7E
    }
    [] -> False
  }
}

fn csi_key(params: String, final: String) -> String {
  let #(p1, p2) = split_params(params)
  let base = case final {
    "A" -> "up"
    "B" -> "down"
    "C" -> "right"
    "D" -> "left"
    "H" -> "home"
    "F" -> "end"
    "Z" -> "backtab"
    "P" -> "f1"
    "Q" -> "f2"
    "R" -> "f3"
    "S" -> "f4"
    "~" -> tilde_key(p1)
    other -> other
  }
  modifier_prefix(p2) <> base
}

fn split_params(params: String) -> #(String, String) {
  case params {
    "" -> #("", "")
    _ ->
      case string.split(params, ";") {
        [] -> #("", "")
        [a] -> #(a, "")
        [a, b, ..] -> #(a, b)
      }
  }
}

fn tilde_key(p1: String) -> String {
  case p1 {
    "1" -> "home"
    "2" -> "insert"
    "3" -> "delete"
    "4" -> "end"
    "5" -> "pageup"
    "6" -> "pagedown"
    "11" -> "f1"
    "12" -> "f2"
    "13" -> "f3"
    "14" -> "f4"
    "15" -> "f5"
    "17" -> "f6"
    "18" -> "f7"
    "19" -> "f8"
    "20" -> "f9"
    "21" -> "f10"
    "23" -> "f11"
    "24" -> "f12"
    other -> other
  }
}

// xterm encodes modifiers as a second parameter, one greater than a bitmask:
// 1 = shift, 2 = alt, 4 = ctrl. So ";5" is ctrl and ";6" is ctrl+shift.
fn modifier_prefix(p2: String) -> String {
  case int.parse(p2) {
    Error(Nil) -> ""
    Ok(n) -> {
      let bits = n - 1
      let ctrl = case int.bitwise_and(bits, 4) != 0 {
        True -> "ctrl+"
        False -> ""
      }
      let alt = case int.bitwise_and(bits, 2) != 0 {
        True -> "alt+"
        False -> ""
      }
      let shift = case int.bitwise_and(bits, 1) != 0 {
        True -> "shift+"
        False -> ""
      }
      ctrl <> alt <> shift
    }
  }
}

// ─────────────────────────────────────────────────────────────────
// Bracketed paste: ESC [ 200 ~ <text> ESC [ 201 ~

fn parse_paste(
  gs: List(String),
  rev: List(String),
) -> Result(#(InputEvent, List(String)), Nil) {
  case gs {
    // Terminator not seen yet: the paste is still arriving.
    [] -> Error(Nil)
    ["\u{001B}", "[", "2", "0", "1", "~", ..rest] ->
      Ok(#(Paste(string.concat(list.reverse(rev))), rest))
    [g, ..rest] -> parse_paste(rest, [g, ..rev])
  }
}

// ─────────────────────────────────────────────────────────────────
// SGR mouse: ESC [ < Cb ; Cx ; Cy (M|m)

fn parse_sgr_mouse(
  body: List(String),
) -> Result(#(InputEvent, List(String)), Nil) {
  use #(params, final, rest) <- result.try(collect_csi(body, []))
  case string.split(params, ";") {
    [cb_s, cx_s, cy_s] ->
      case int.parse(cb_s), int.parse(cx_s), int.parse(cy_s) {
        Ok(cb), Ok(cx), Ok(cy) ->
          // SGR coordinates are 1-based.
          Ok(#(mouse_event(cb, cx - 1, cy - 1, final == "M"), rest))
        _, _, _ -> Ok(#(KeyPress(esc <> "[<" <> params <> final), rest))
      }
    _ -> Ok(#(KeyPress(esc <> "[<" <> params <> final), rest))
  }
}

// Cb is a bitfield: bits 0-1 are the button (3 = none), bit 5 marks a motion
// event, bit 6 marks the wheel. Bits 2-4 are shift/alt/ctrl, which do not
// change which button is reported.
fn mouse_event(cb: Int, x: Int, y: Int, pressed: Bool) -> InputEvent {
  let button_bits = int.bitwise_and(cb, 3)
  let motion = int.bitwise_and(cb, 32) != 0
  let wheel = int.bitwise_and(cb, 64) != 0
  case wheel, motion, button_bits {
    True, _, b -> MouseScroll(x, y, b == 0)
    // Button 3 during motion means no button is held: a plain move.
    False, True, 3 -> MouseMove(x, y)
    False, True, b -> MouseDrag(x, y, button_of(b))
    False, False, b ->
      case pressed {
        True -> MousePress(x, y, button_of(b))
        False -> MouseRelease(x, y, button_of(b))
      }
  }
}

fn button_of(bits: Int) -> backend.MouseButton {
  case bits {
    1 -> MouseMiddle
    2 -> MouseRight
    _ -> MouseLeft
  }
}

// ─────────────────────────────────────────────────────────────────
// Single characters

fn simple_key(g: String) -> String {
  case g {
    "\r" | "\n" -> "enter"
    "\t" -> "tab"
    // 0x08 is both Ctrl+H and Backspace on most terminals; Backspace wins.
    "\u{007F}" | "\u{0008}" -> "backspace"
    _ -> control_key(g)
  }
}

fn control_key(g: String) -> String {
  case string.to_utf_codepoints(g) {
    [cp] -> {
      let n = string.utf_codepoint_to_int(cp)
      case n >= 1 && n <= 26 {
        True -> "ctrl+" <> letter_of(n)
        False -> g
      }
    }
    _ -> g
  }
}

// Ctrl+A is 1 and 'a' is digit 10 in base 36, so the offset lines the two up.
fn letter_of(n: Int) -> String {
  string.lowercase(int.to_base36(n + 9))
}
