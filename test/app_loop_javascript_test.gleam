@target(javascript)
/// Exercises the asynchronous JavaScript app loops against an in-memory
/// backend. The ordinary test runner awaits returned promises on this target.
import etui/app
@target(javascript)
import etui/backend
@target(javascript)
import etui/buffer
@target(javascript)
import gleam/javascript/promise
@target(javascript)
import gleeunit/should

@target(javascript)
type MockState {
  MockState(
    events: List(backend.InputEvent),
    expected_timeouts: List(Int),
    renders: Int,
    max_renders: Int,
  )
}

@target(javascript)
type Counter {
  Counter(count: Int, quit: Bool)
}

@target(javascript)
fn mock_backend(
  events: List(backend.InputEvent),
  expected_timeouts: List(Int),
) -> backend.AsyncBackend(MockState) {
  mock_backend_with_limit(events, expected_timeouts, -1)
}

@target(javascript)
fn mock_backend_with_limit(
  events: List(backend.InputEvent),
  expected_timeouts: List(Int),
  max_renders: Int,
) -> backend.AsyncBackend(MockState) {
  backend.AsyncBackend(
    init: fn() {
      Ok(MockState(
        events: events,
        expected_timeouts: expected_timeouts,
        renders: 0,
        max_renders: max_renders,
      ))
    },
    render: fn(state, _ops) {
      let renders = state.renders + 1
      case state.max_renders >= 0 && renders > state.max_renders {
        True -> Error(backend.IOError("too many renders"))
        False -> Ok(MockState(..state, renders: renders))
      }
    },
    poll: fn(state, timeout) {
      let result = case state.expected_timeouts, state.events {
        [expected, ..timeouts], [event, ..events] if expected == timeout ->
          Ok(#(
            event,
            MockState(..state, events: events, expected_timeouts: timeouts),
          ))
        _, _ -> Error(backend.Interrupted)
      }
      promise.resolve(result)
    },
    next_size: fn(state) {
      Ok(#(backend.TerminalSize(width: 80, height: 24), state))
    },
    cleanup: fn(_state) { Nil },
  )
}

@target(javascript)
fn update(event: backend.InputEvent, model: Counter) -> Counter {
  case event {
    backend.KeyPress("q") -> Counter(..model, quit: True)
    backend.KeyPress(_) -> Counter(..model, count: model.count + 1)
    _ -> model
  }
}

@target(javascript)
fn should_quit(model: Counter) -> Bool {
  model.quit
}

@target(javascript)
fn timeout(model: Counter) -> Int {
  100 + model.count
}

@target(javascript)
fn events() -> List(backend.InputEvent) {
  [backend.KeyPress("x"), backend.Tick, backend.KeyPress("q")]
}

@target(javascript)
fn assert_finished(
  result: promise.Promise(app.AppResult(Counter)),
) -> promise.Promise(Nil) {
  promise.map(result, fn(value) {
    value |> should.equal(app.Success(Counter(count: 1, quit: True)))
  })
}

@target(javascript)
pub fn run_adaptive_reevaluates_timeout_from_current_state_test() {
  app.run_adaptive(
    mock_backend([backend.KeyPress("x"), backend.KeyPress("q")], [100, 101]),
    Counter(count: 0, quit: False),
    fn(_model) { [] },
    update,
    should_quit,
    timeout,
  )
  |> assert_finished
}

@target(javascript)
pub fn run_buffered_adaptive_reevaluates_timeout_test() {
  app.run_buffered_adaptive(
    mock_backend(events(), [100, 0, 101]),
    Counter(count: 0, quit: False),
    fn(_model, screen) { buffer.buffer_new(screen) },
    update,
    should_quit,
    timeout,
  )
  |> assert_finished
}

@target(javascript)
pub fn run_animated_adaptive_reevaluates_timeout_test() {
  app.run_animated_adaptive(
    mock_backend(events(), [100, 0, 101]),
    Counter(count: 0, quit: False),
    fn(_model, screen, _animation) { buffer.buffer_new(screen) },
    update,
    should_quit,
    timeout,
  )
  |> assert_finished
}

@target(javascript)
pub fn run_buffered_cursor_adaptive_reevaluates_timeout_test() {
  app.run_buffered_cursor_adaptive(
    mock_backend(events(), [100, 0, 101]),
    Counter(count: 0, quit: False),
    fn(_model, screen) { #(buffer.buffer_new(screen), Error(Nil)) },
    update,
    should_quit,
    timeout,
  )
  |> assert_finished
}

@target(javascript)
pub fn run_buffered_coalesces_ready_input_before_redraw_test() {
  app.run_buffered(
    mock_backend_with_limit(
      [backend.KeyPress("x"), backend.KeyPress("q")],
      [16, 0],
      2,
    ),
    Counter(count: 0, quit: False),
    fn(_model, screen) { buffer.buffer_new(screen) },
    update,
    should_quit,
    16,
  )
  |> assert_finished
}
