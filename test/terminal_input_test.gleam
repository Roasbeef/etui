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

// Only a fake I/O group leader that never answers keeps the keyboard reader
// quiet, so a poll can end early only by a wake.
@target(erlang)
@external(erlang, "etui_input_test_ffi", "with_silent_input")
fn with_silent_input(action: fn() -> a) -> a

@target(erlang)
@external(erlang, "etui_input_test_ffi", "wake_self")
fn wake_self() -> Nil

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

// The poll's timeout is a minute, far past the test runner's own deadline,
// so the test passes only if the wake ends the read.
@target(erlang)
pub fn a_wake_ends_a_waiting_poll_with_a_tick_test() {
  let #(event, state) =
    with_silent_input(fn() {
      wake_self()
      let assert Ok(polled) = erlang.new().poll(quiet_state(""), 60_000)
      polled
    })
  event |> should.equal(backend.Tick)
  state.pending |> should.equal("")
}

// A wake is not a timeout. A lone Escape byte may be the start of a longer
// sequence whose rest is still in flight, so the first wake keeps it, as a
// zero-wait probe would, and only a second empty read resolves it.
@target(erlang)
pub fn a_wake_defers_a_pending_escape_as_a_zero_wait_probe_test() {
  let #(first, second) =
    with_silent_input(fn() {
      let backend = erlang.new()
      wake_self()
      let assert Ok(#(first, state)) =
        backend.poll(quiet_state("\u{001B}"), 60_000)
      state.pending |> should.equal("\u{001B}")
      state.pending_deferred |> should.equal(True)
      wake_self()
      let assert Ok(#(second, _)) = backend.poll(state, 60_000)
      #(first, second)
    })
  first |> should.equal(backend.Tick)
  second |> should.equal(backend.KeyPress("esc"))
}

@target(erlang)
fn quiet_state(pending: String) -> erlang.ErlangTerminalState {
  erlang.ErlangTerminalState(
    raw_mode_active: False,
    cols: 80,
    rows: 24,
    mouse: False,
    last_size_check: 0,
    last_size_change: 0,
    pending:,
    pending_deferred: False,
    queue: [],
  )
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
