@target(erlang)
/// Measures the frame cost of delivering one input burst.
///
/// Run with `gleam run -m etui_burst_bench`. Both cases replay forty ready
/// key events through the same in-memory terminal backend. The first draws
/// after each event, matching the old buffered loop. The second collects at
/// most sixty-four ready events and draws once after applying the batch.
/// Terminal setup and the initial repaint happen before the timed region.
import etui/backend
@target(erlang)
import etui/buffer
@target(erlang)
import etui/geometry.{type Rect, Position}
@target(erlang)
import etui/style
@target(erlang)
import etui/terminal
@target(erlang)
import gleam/float
@target(erlang)
import gleam/int
@target(erlang)
import gleam/io
@target(erlang)
import gleam/list
@target(erlang)
import gleam/string

@target(erlang)
type Script {
  Script(events: List(backend.InputEvent))
}

@target(erlang)
type RenderMode {
  Cached(buffer.Buffer)
  Rebuilt
}

@target(erlang)
@external(erlang, "erlang", "monotonic_time")
fn now_native(unit: Micro) -> Int

@target(erlang)
type Micro {
  Microsecond
}

@target(erlang)
fn now_us() -> Int {
  now_native(Microsecond)
}

@target(erlang)
fn scripted_backend(
  events: List(backend.InputEvent),
) -> backend.Backend(Script) {
  backend.Backend(
    init: fn() { Ok(Script(events)) },
    render: fn(state, _ops) { Ok(state) },
    poll: fn(state, _timeout_ms) {
      case state.events {
        [event, ..rest] -> Ok(#(event, Script(rest)))
        [] -> Error(backend.Interrupted)
      }
    },
    next_size: fn(state) {
      Ok(#(backend.TerminalSize(width: 200, height: 50), state))
    },
    cleanup: fn(_state) { Nil },
  )
}

@target(erlang)
fn filled(area: Rect, frame: Int) -> buffer.Buffer {
  buffer.buffer_new_filled(
    area,
    string.repeat("the quick brown fox ", 500),
    style.new(style.Indexed(7), style.Default, style.none()),
  )
  |> buffer.set_string(
    Position(0, 0),
    int.to_string(frame),
    style.new(style.Indexed(1), style.Default, style.none()),
  )
}

@target(erlang)
fn draw(
  term: terminal.Terminal(Script),
  frame: Int,
  mode: RenderMode,
) -> terminal.Terminal(Script) {
  let assert Ok(drawn) =
    terminal.draw(term, fn(canvas) {
      let next = case mode {
        Cached(cached) -> cached
        Rebuilt -> filled(canvas.area, frame)
      }
      terminal.with_buffer(canvas, next)
      |> terminal.hide_cursor
    })
  drawn
}

@target(erlang)
fn one_event_per_frame(
  term: terminal.Terminal(Script),
  mode: RenderMode,
) -> Int {
  one_event_loop(term, 0, mode).1
}

@target(erlang)
fn one_event_loop(
  term: terminal.Terminal(Script),
  count: Int,
  mode: RenderMode,
) -> #(terminal.Terminal(Script), Int) {
  case terminal.poll(term, 0) {
    Ok(#(_event, polled)) -> {
      let next = count + 1
      one_event_loop(draw(polled, next, mode), next, mode)
    }
    Error(_) -> #(term, count)
  }
}

@target(erlang)
fn bounded_burst(term: terminal.Terminal(Script), mode: RenderMode) -> Int {
  burst_loop(term, 0, mode).1
}

@target(erlang)
fn burst_loop(
  term: terminal.Terminal(Script),
  count: Int,
  mode: RenderMode,
) -> #(terminal.Terminal(Script), Int) {
  case terminal.poll_burst(term, 0, 64) {
    Ok(#(events, polled)) -> {
      let next = count + list.length(events)
      burst_loop(draw(polled, next, mode), next, mode)
    }
    Error(_) -> #(term, count)
  }
}

@target(erlang)
fn repeat(iterations: Int, work: fn() -> Int, total: Int) -> Int {
  case iterations <= 0 {
    True -> total
    False -> repeat(iterations - 1, work, total + work())
  }
}

@target(erlang)
fn bench(name: String, iterations: Int, work: fn() -> Int) -> Nil {
  let _ = work()
  let started = now_us()
  let total_events = repeat(iterations, work, 0)
  let elapsed = now_us() - started
  let per_burst = int.to_float(elapsed) /. int.to_float(iterations)
  io.println(
    name
    <> ": "
    <> float.to_string(round2(per_burst))
    <> " us per 40-event burst ("
    <> int.to_string(total_events)
    <> " events)",
  )
}

@target(erlang)
fn round2(value: Float) -> Float {
  int.to_float(float.round(value *. 100.0)) /. 100.0
}

@target(erlang)
pub fn main() -> Nil {
  let area = terminal_area()
  let cached = filled(area, 0)
  let cached_mode = Cached(cached)
  let cached_term = ready(cached_mode)
  let rebuilt_term = ready(Rebuilt)

  io.println("etui input burst budget")
  bench("one event/frame, exact cached buffer", 2000, fn() {
    one_event_per_frame(cached_term, cached_mode)
  })
  bench("bounded burst, exact cached buffer", 2000, fn() {
    bounded_burst(cached_term, cached_mode)
  })
  bench("one event/frame, rebuilt 200x50 buffer", 30, fn() {
    one_event_per_frame(rebuilt_term, Rebuilt)
  })
  bench("bounded burst, rebuilt 200x50 buffer", 30, fn() {
    bounded_burst(rebuilt_term, Rebuilt)
  })
}

@target(erlang)
fn ready(mode: RenderMode) -> terminal.Terminal(Script) {
  let events = list.repeat(backend.KeyPress("j"), 40)
  let assert Ok(term) = terminal.new(scripted_backend(events))
  draw(term, 0, mode)
}

@target(erlang)
fn terminal_area() -> Rect {
  geometry.rect_new(0, 0, 200, 50)
}
