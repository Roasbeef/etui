//// Terminal replies that reach the input parser are dropped, not delivered
//// as key presses. A graphics probe stops waiting at its deadline, and an
//// answer that arrives after it is read by the backend like any other input.

import etui/backend.{KeyPress, MouseMove}
import etui/input
import gleeunit/should

const esc = "\u{001B}"

fn kitty_answer() -> String {
  esc
  <> "_Gi=31;OK"
  <> esc
  <> "\\"
  <> esc
  <> "P>|kitty(0.39.1)"
  <> esc
  <> "\\"
  <> esc
  <> "[6;21;10t"
  <> esc
  <> "[?62;22;52c"
}

fn keys_of(chunk: String) -> List(backend.InputEvent) {
  let input.Parsed(events, _) = input.parse(chunk)
  events
}

pub fn a_late_answer_never_reaches_the_app_as_keys_test() {
  keys_of("a" <> kitty_answer() <> "b")
  |> should.equal([KeyPress("a"), KeyPress("b")])
}

pub fn a_late_reply_split_across_reads_is_held_then_dropped_test() {
  let input.Parsed(events, rest) = input.parse("a" <> esc <> "_Gi=31;O")
  events |> should.equal([KeyPress("a")])
  rest |> should.equal(esc <> "_Gi=31;O")
  let input.Parsed(events, rest) = input.parse(rest <> "K" <> esc <> "\\b")
  events |> should.equal([KeyPress("b")])
  rest |> should.equal("")
}

pub fn keys_that_share_an_introducer_still_arrive_test() {
  // Alt+underscore, Alt+Shift+P, an arrow and a mouse move are unchanged.
  keys_of(esc <> "_") |> should.equal([KeyPress("alt+_")])
  keys_of(esc <> "P") |> should.equal([KeyPress("alt+P")])
  keys_of(esc <> "_x") |> should.equal([KeyPress("alt+_"), KeyPress("x")])
  keys_of(esc <> "[A") |> should.equal([KeyPress("up")])
  keys_of(esc <> "[<35;10;5M") |> should.equal([MouseMove(9, 4)])
}

pub fn alt_underscore_then_a_typed_g_is_still_keys_test() {
  // `G` alone used to commit to a kitty reply and hold every key after it
  // until the next ESC. A kitty reply always starts `G i =`.
  let input.Parsed(events, rest) = input.parse(esc <> "_Gx")
  events
  |> should.equal([KeyPress("alt+_"), KeyPress("G"), KeyPress("x")])
  rest |> should.equal("")
}
