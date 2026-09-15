@target(erlang)
import etui/backend
@target(erlang)
import etui/backend/erlang
@target(erlang)
import gleeunit/should

@target(erlang)
type ClosedInput {
  Eof
  Failed
}

// Only a fake I/O group leader can distinguish EOF from an empty chunk
// without borrowing the test runner's terminal or creating an unbounded loop.
@target(erlang)
@external(erlang, "etui_input_test_ffi", "with_closed_input")
fn with_closed_input(kind: ClosedInput, action: fn() -> a) -> a

@target(erlang)
pub fn end_of_input_stops_the_native_backend_test() {
  with_closed_input(Eof, poll_closed)
  |> should.equal(Error(backend.IOError("terminal input is closed")))
}

@target(erlang)
pub fn failed_input_stops_the_native_backend_test() {
  with_closed_input(Failed, poll_closed)
  |> should.equal(Error(backend.IOError("terminal input is closed")))
}

@target(erlang)
fn poll_closed() {
  let state =
    erlang.ErlangTerminalState(
      raw_mode_active: False,
      cols: 80,
      rows: 24,
      mouse: False,
      last_size_check: 0,
      last_size_change: 0,
      pending: "",
      pending_deferred: False,
      queue: [],
    )
  erlang.new().poll(state, 1000)
}
