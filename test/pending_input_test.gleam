/// Checks the boundary between non-blocking input probes and Escape-key
/// disambiguation without requiring a real terminal.
import etui/backend.{KeyPress}
import etui/backend/pending_input
import gleeunit/should

pub fn a_nonblocking_probe_preserves_an_ambiguous_escape_once_test() {
  pending_input.after_empty_read("\u{001B}", 0, False)
  |> should.equal(#([], "\u{001B}", True))
}

pub fn a_second_nonblocking_probe_resolves_the_escape_test() {
  pending_input.after_empty_read("\u{001B}", 0, True)
  |> should.equal(#([KeyPress("esc")], "", False))
}

pub fn a_waiting_poll_resolves_the_escape_immediately_test() {
  pending_input.after_empty_read("\u{001B}", 16, False)
  |> should.equal(#([KeyPress("esc")], "", False))
}

pub fn an_empty_remainder_never_creates_input_test() {
  pending_input.after_empty_read("", 0, True)
  |> should.equal(#([], "", False))
}
