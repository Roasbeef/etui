/// Terminal input parsing. Everything here is pure, no TTY involved.
import etui/backend.{
  KeyPress, MouseDrag, MouseLeft, MouseMiddle, MouseMove, MousePress,
  MouseRelease, MouseRight, MouseScroll, Paste,
}
import etui/input.{Parsed}
import gleeunit/should

fn events(chunk: String) -> List(backend.InputEvent) {
  let Parsed(events, _) = input.parse(chunk)
  events
}

fn remainder(chunk: String) -> String {
  let Parsed(_, rest) = input.parse(chunk)
  rest
}

fn keys(chunk: String) -> List(String) {
  events(chunk)
  |> keys_of
}

fn keys_of(evs: List(backend.InputEvent)) -> List(String) {
  case evs {
    [] -> []
    [KeyPress(k), ..rest] -> [k, ..keys_of(rest)]
    [_, ..rest] -> ["<not a key>", ..keys_of(rest)]
  }
}

// ─────────────────────────────────────────────────────────────────
// The regression this module exists for

pub fn a_burst_of_typing_yields_one_event_per_key_test() {
  // A single read returns whatever was buffered. Treating the chunk as one key
  // press dropped everything but the first, which is what fast typing and
  // pasting looked like.
  keys("hello")
  |> should.equal(["h", "e", "l", "l", "o"])
}

pub fn a_burst_mixing_text_and_sequences_test() {
  keys("a\u{001B}[Ab\u{001B}[Bc")
  |> should.equal(["a", "up", "b", "down", "c"])
}

pub fn held_arrow_key_repeats_test() {
  keys("\u{001B}[A\u{001B}[A\u{001B}[A")
  |> should.equal(["up", "up", "up"])
}

// ─────────────────────────────────────────────────────────────────
// Incomplete sequences

pub fn a_split_escape_sequence_is_held_back_test() {
  events("\u{001B}[")
  |> should.equal([])
  remainder("\u{001B}[")
  |> should.equal("\u{001B}[")
}

pub fn a_sequence_split_across_reads_survives_test() {
  // First read ends mid-sequence; its remainder is prepended to the next.
  let Parsed(first, rest) = input.parse("ab\u{001B}")
  keys_of(first)
  |> should.equal(["a", "b"])
  keys(rest <> "[C")
  |> should.equal(["right"])
}

pub fn text_before_an_incomplete_sequence_is_not_lost_test() {
  keys("xy\u{001B}[1;5")
  |> should.equal(["x", "y"])
}

pub fn a_lone_escape_becomes_esc_once_no_more_input_arrives_test() {
  // parse cannot tell Escape from the start of a sequence; only a timeout can.
  remainder("\u{001B}")
  |> should.equal("\u{001B}")
  input.flush("\u{001B}")
  |> should.equal([KeyPress("esc")])
}

pub fn flushing_nothing_yields_nothing_test() {
  input.flush("")
  |> should.equal([])
}

// ─────────────────────────────────────────────────────────────────
// Named keys

pub fn control_characters_test() {
  keys("\r")
  |> should.equal(["enter"])
  keys("\n")
  |> should.equal(["enter"])
  keys("\t")
  |> should.equal(["tab"])
  keys("\u{007F}")
  |> should.equal(["backspace"])
}

pub fn ctrl_letters_test() {
  keys("\u{0001}\u{0003}\u{001A}")
  |> should.equal(["ctrl+a", "ctrl+c", "ctrl+z"])
}

pub fn alt_letter_test() {
  keys("\u{001B}x")
  |> should.equal(["alt+x"])
}

pub fn arrows_in_both_encodings_test() {
  keys("\u{001B}[A\u{001B}OA")
  |> should.equal(["up", "up"])
}

pub fn navigation_keys_test() {
  keys("\u{001B}[2~\u{001B}[3~\u{001B}[5~\u{001B}[6~\u{001B}[H\u{001B}[F")
  |> should.equal(["insert", "delete", "pageup", "pagedown", "home", "end"])
}

pub fn function_keys_test() {
  keys("\u{001B}OP\u{001B}[15~\u{001B}[24~")
  |> should.equal(["f1", "f5", "f12"])
}

pub fn backtab_test() {
  keys("\u{001B}[Z")
  |> should.equal(["backtab"])
}

// ─────────────────────────────────────────────────────────────────
// Modified keys, which the old backend surfaced as raw escape text

pub fn modified_arrows_test() {
  keys("\u{001B}[1;5C")
  |> should.equal(["ctrl+right"])
  keys("\u{001B}[1;2D")
  |> should.equal(["shift+left"])
  keys("\u{001B}[1;3A")
  |> should.equal(["alt+up"])
}

pub fn combined_modifiers_keep_a_stable_order_test() {
  // bits = 6 - 1 = 5 = ctrl | shift
  keys("\u{001B}[1;6B")
  |> should.equal(["ctrl+shift+down"])
  // bits = 8 - 1 = 7 = ctrl | alt | shift
  keys("\u{001B}[1;8B")
  |> should.equal(["ctrl+alt+shift+down"])
}

pub fn modified_navigation_keys_test() {
  keys("\u{001B}[3;5~")
  |> should.equal(["ctrl+delete"])
}

// ─────────────────────────────────────────────────────────────────
// Mouse

pub fn mouse_press_and_release_test() {
  events("\u{001B}[<0;10;5M")
  |> should.equal([MousePress(9, 4, MouseLeft)])
  events("\u{001B}[<0;10;5m")
  |> should.equal([MouseRelease(9, 4, MouseLeft)])
}

pub fn mouse_buttons_test() {
  events("\u{001B}[<1;1;1M")
  |> should.equal([MousePress(0, 0, MouseMiddle)])
  events("\u{001B}[<2;1;1M")
  |> should.equal([MousePress(0, 0, MouseRight)])
}

pub fn mouse_modifiers_do_not_change_the_button_test() {
  // Cb 4 is shift+left, 16 is ctrl+left. Both are still the left button.
  events("\u{001B}[<4;1;1M")
  |> should.equal([MousePress(0, 0, MouseLeft)])
  events("\u{001B}[<16;1;1M")
  |> should.equal([MousePress(0, 0, MouseLeft)])
}

pub fn drag_is_not_a_press_test() {
  // Cb 32 is motion with the left button held. It used to arrive as a press,
  // so a drag looked like a stream of clicks.
  events("\u{001B}[<32;3;7M")
  |> should.equal([MouseDrag(2, 6, MouseLeft)])
}

pub fn motion_without_a_button_is_a_move_test() {
  // Cb 35 is motion with button bits 3, meaning no button held.
  events("\u{001B}[<35;3;7M")
  |> should.equal([MouseMove(2, 6)])
}

pub fn scroll_test() {
  events("\u{001B}[<64;1;1M")
  |> should.equal([MouseScroll(0, 0, True)])
  events("\u{001B}[<65;1;1M")
  |> should.equal([MouseScroll(0, 0, False)])
}

pub fn scroll_with_a_modifier_is_still_a_scroll_test() {
  // Cb 68 is shift+wheel-up. The old decoder only knew 64 and 65 and reported
  // this as a button press.
  events("\u{001B}[<68;1;1M")
  |> should.equal([MouseScroll(0, 0, True)])
}

pub fn a_split_mouse_sequence_is_held_back_test() {
  events("\u{001B}[<0;10")
  |> should.equal([])
  remainder("\u{001B}[<0;10")
  |> should.equal("\u{001B}[<0;10")
}

// ─────────────────────────────────────────────────────────────────
// Bracketed paste

pub fn paste_arrives_as_one_event_test() {
  events("\u{001B}[200~hello world\u{001B}[201~")
  |> should.equal([Paste("hello world")])
}

pub fn paste_keeps_newlines_instead_of_submitting_test() {
  // The whole point: a pasted newline must not look like the user pressing
  // Enter, which would submit a form mid-paste.
  events("\u{001B}[200~a\nb\u{001B}[201~")
  |> should.equal([Paste("a\nb")])
}

pub fn an_unterminated_paste_is_held_back_whole_test() {
  events("\u{001B}[200~partial")
  |> should.equal([])
  remainder("\u{001B}[200~partial")
  |> should.equal("\u{001B}[200~partial")
}

pub fn keys_around_a_paste_are_kept_test() {
  keys_of(events("a\u{001B}[200~X\u{001B}[201~b"))
  |> should.equal(["a", "<not a key>", "b"])
}

// ─────────────────────────────────────────────────────────────────
// Unicode

pub fn multibyte_characters_are_single_events_test() {
  keys("日本")
  |> should.equal(["日", "本"])
}

pub fn emoji_is_one_event_test() {
  keys("👍")
  |> should.equal(["👍"])
}
