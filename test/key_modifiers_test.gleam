/// Modified keys as data rather than as strings.
///
/// The input parser has delivered `"shift+left"` and `"ctrl+shift+down"` since
/// the input work, but `Key` had nowhere to put the modifier, so `match`
/// answered `Unknown` and callers had to compare raw strings. `parse` returns
/// the key and what was held with it.
import etui/keys.{
  Alt, Char, Ctrl, Down, F, KeyEvent, Left, Modifiers, Right, Unknown, Up,
}
import gleam/list
import gleeunit/should

// ─────────────────────────────────────────────────────────────────
// The gap this closes

pub fn a_modified_named_key_is_readable_test() {
  keys.parse("shift+left")
  |> should.equal(KeyEvent(code: Left, modifiers: keys.shift()))
}

pub fn match_still_cannot_say_it_test() {
  // Kept as the counter-test: this is exactly why parse exists.
  keys.match("shift+left")
  |> should.equal(Unknown("shift+left"))
}

pub fn several_modifiers_are_all_reported_test() {
  keys.parse("ctrl+alt+shift+down")
  |> should.equal(KeyEvent(
    code: Down,
    modifiers: Modifiers(ctrl: True, alt: True, shift: True),
  ))
}

pub fn modifiers_are_read_in_any_order_test() {
  keys.parse("shift+ctrl+up")
  |> should.equal(keys.parse("ctrl+shift+up"))
}

// ─────────────────────────────────────────────────────────────────
// Plain keys

pub fn an_unmodified_key_carries_no_modifiers_test() {
  let event = keys.parse("left")
  event.code
  |> should.equal(Left)
  keys.is_plain(event.modifiers)
  |> should.equal(True)
}

pub fn a_character_is_a_character_test() {
  keys.parse("a")
  |> should.equal(KeyEvent(code: Char("a"), modifiers: keys.no_modifiers()))
}

pub fn a_function_key_survives_a_modifier_test() {
  keys.parse("ctrl+f5")
  |> should.equal(KeyEvent(code: F(5), modifiers: keys.ctrl()))
}

// ─────────────────────────────────────────────────────────────────
// Agreeing with match where match can speak

pub fn parse_and_match_agree_on_plain_keys_test() {
  list.each(
    ["up", "down", "enter", "esc", "f7", "home", "pagedown", "a", "€"],
    fn(raw) {
      keys.parse(raw).code
      |> should.equal(keys.match(raw))
    },
  )
}

pub fn match_still_answers_ctrl_for_a_modified_character_test() {
  // Ctrl("c") is the shape existing code matches on, and it keeps working.
  keys.match("ctrl+c")
  |> should.equal(Ctrl("c"))
  keys.match("alt+f")
  |> should.equal(Alt("f"))
}

pub fn parse_reports_the_same_thing_as_a_key_plus_a_modifier_test() {
  keys.parse("ctrl+c")
  |> should.equal(KeyEvent(code: Char("c"), modifiers: keys.ctrl()))
}

// ─────────────────────────────────────────────────────────────────
// Asking questions of an event

pub fn pressed_matches_only_the_unmodified_key_test() {
  keys.pressed(keys.parse("left"), Left)
  |> should.equal(True)
  keys.pressed(keys.parse("shift+left"), Left)
  |> should.equal(False)
}

pub fn pressed_with_matches_the_exact_combination_test() {
  keys.pressed_with(keys.parse("ctrl+right"), Right, keys.ctrl())
  |> should.equal(True)
  keys.pressed_with(keys.parse("ctrl+shift+right"), Right, keys.ctrl())
  |> should.equal(False)
}

// ─────────────────────────────────────────────────────────────────
// Round-tripping

pub fn a_key_event_names_itself_the_way_it_arrived_test() {
  list.each(
    [
      "up", "shift+left", "ctrl+right", "ctrl+alt+shift+down", "f12", "ctrl+f5",
      "a", "enter",
    ],
    fn(raw) {
      keys.to_string(keys.parse(raw))
      |> should.equal(raw)
    },
  )
}

pub fn the_modifier_order_is_fixed_test() {
  // Whatever order they arrived in, they are named ctrl, alt, shift.
  keys.to_string(keys.parse("shift+alt+ctrl+up"))
  |> should.equal("ctrl+alt+shift+up")
}

// ─────────────────────────────────────────────────────────────────
// Edges

pub fn a_bare_modifier_prefix_is_not_a_key_test() {
  keys.parse("ctrl+").code
  |> should.equal(Unknown("ctrl+"))
}

pub fn an_unrecognised_name_stays_unknown_test() {
  keys.parse("kitty").code
  |> should.equal(Unknown("kitty"))
}

pub fn a_plus_sign_is_still_a_character_test() {
  keys.parse("+")
  |> should.equal(KeyEvent(code: Char("+"), modifiers: keys.no_modifiers()))
  keys.parse("ctrl++")
  |> should.equal(KeyEvent(code: Char("+"), modifiers: keys.ctrl()))
}

pub fn a_wide_character_is_one_character_test() {
  keys.parse("漢").code
  |> should.equal(Char("漢"))
}

pub fn every_named_key_round_trips_test() {
  list.each(
    [
      Up,
      Down,
      Left,
      Right,
      keys.Enter,
      keys.Backspace,
      keys.Delete,
      keys.Tab,
      keys.BackTab,
      keys.Home,
      keys.End,
      keys.PageUp,
      keys.PageDown,
      keys.Escape,
      keys.Insert,
      F(1),
      F(12),
    ],
    fn(code) {
      let event = KeyEvent(code: code, modifiers: keys.shift())
      keys.parse(keys.to_string(event))
      |> should.equal(event)
    },
  )
}
