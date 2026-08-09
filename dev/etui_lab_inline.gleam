/// LAB INLINE, the same bench in six rows instead of the whole screen.
///
/// Run: gleam run -m etui_lab_inline
///
/// An inline viewport cannot be shown from inside a full-screen app, because
/// the thing worth seeing is that it is *not* full screen. So this is a second
/// entry point rather than a sixth screen: run it from a shell with some
/// output already on it and watch that
///
///   - the lines above it keep their scrollback, untouched;
///   - the panel updates in place while they sit still;
///   - after `q` the panel is still there and the prompt carries on below it,
///     rather than the screen being handed back and the output vanishing.
///
/// That last point is the difference from `Fullscreen`, and it is why a build
/// tool or an installer wants this shape.
import etui/backend
import etui/backend/default
import etui/buffer
import etui/geometry.{type Rect, Fill, Length, Percentage}
import etui/span
import etui/style
import etui/terminal
import etui/widgets/block
import etui/widgets/gauge
import gleam/int
import gleam/io
import gleam/list

@target(javascript)
import gleam/javascript/promise

const accent = style.Indexed(51)

const muted = style.Indexed(240)

const good = style.Indexed(82)

/// Rows the panel asks for. Small on purpose: an inline app that takes half
/// the screen has misunderstood the point.
pub const rows = 6

pub type Model {
  Model(
    /// Frames seen, which drives the progress bar.
    ticks: Int,
    /// The last key, shown so the panel is visibly live.
    last_key: String,
    quit: Bool,
  )
}

pub fn initial() -> Model {
  Model(ticks: 0, last_key: "none yet", quit: False)
}

pub fn update(event: backend.InputEvent, m: Model) -> Model {
  case event {
    backend.KeyPress("q") -> Model(..m, quit: True)
    backend.KeyPress("ctrl+c") -> Model(..m, quit: True)
    backend.KeyPress(k) -> Model(..m, last_key: k, ticks: m.ticks + 1)
    backend.Tick -> Model(..m, ticks: m.ticks + 1)
    _ -> m
  }
}

fn percent(m: Model) -> Int {
  m.ticks % 101
}

pub fn render(m: Model, area: Rect) -> buffer.Buffer {
  let buf = buffer.buffer_new(area)
  let blk =
    block.block_new()
    |> block.with_border(block.Rounded)
    |> block.with_title(" INLINE VIEWPORT ", block.Top)
    |> block.with_colors(accent, style.Default)
  let inner = block.inner(area, blk)
  let buf = block.render(buf, area, blk)

  case geometry.split_v(inner, [Length(1), Length(1), Fill]) {
    [bar_row, key_row, hint_row] -> {
      let split = geometry.split_h(bar_row, [Percentage(70), Fill])
      let buf = case split {
        [bar_area, label_area] ->
          buf
          |> gauge.render(
            bar_area,
            gauge.gauge_new(percent(m))
              |> gauge.with_colors(good, style.Indexed(236)),
          )
          |> line(label_area, [
            tinted(
              " " <> int.to_string(percent(m)) <> "% of nothing in particular",
              muted,
            ),
          ])
        _ -> buf
      }
      buf
      |> line(key_row, [
        tinted("last key  ", muted),
        span.span_plain(m.last_key),
        tinted("    frames ", muted),
        span.span_plain(int.to_string(m.ticks)),
      ])
      |> line(hint_row, [
        tinted(
          "the lines above are untouched; q leaves this panel where it is",
          muted,
        ),
      ])
    }
    _ -> buf
  }
}

fn tinted(s: String, c: style.Color) -> span.Span {
  span.span_plain(s) |> span.span_fg(c)
}

fn line(
  area: Rect,
  spans: List(span.Span),
) -> fn(buffer.Buffer) -> buffer.Buffer {
  fn(buf) {
    span.render_line(
      buf,
      geometry.Position(x: area.position.x, y: area.position.y),
      span.line_new(spans),
      area.size.width,
    )
  }
}

// A little context above the panel, so there is scrollback to not disturb.
fn preamble() -> Nil {
  list.each(
    [
      "etui inline viewport demo",
      "",
      "These lines were printed by the shell before the panel opened.",
      "They must keep their place while the panel below updates, and they",
      "must still be here after it exits.",
      "",
    ],
    io.println,
  )
}

@target(erlang)
pub fn main() -> Nil {
  preamble()
  case terminal.new_with_viewport(default.new(), terminal.Inline(rows)) {
    Error(_) -> io.println("could not open the terminal")
    Ok(term) -> {
      terminal.restore(run(term, initial()))
      io.println("panel closed, and it is still above this line")
    }
  }
}

@target(erlang)
fn run(term: terminal.Terminal(bs), m: Model) -> terminal.Terminal(bs) {
  case
    terminal.draw(term, fn(frame) {
      terminal.with_buffer(frame, render(m, frame.area))
    })
  {
    Error(_) -> term
    Ok(drawn) ->
      case terminal.poll(drawn, 60) {
        Error(_) -> drawn
        Ok(#(event, polled)) -> {
          let next = update(event, m)
          case next.quit {
            True -> polled
            False -> run(polled, next)
          }
        }
      }
  }
}

@target(javascript)
pub fn main() -> promise.Promise(Nil) {
  preamble()
  case terminal.new_with_viewport(default.new(), terminal.Inline(rows)) {
    Error(_) -> {
      io.println("could not open the terminal")
      promise.resolve(Nil)
    }
    Ok(term) ->
      promise.map(run(term, initial()), fn(final) {
        terminal.restore(final)
        io.println("panel closed, and it is still above this line")
      })
  }
}

@target(javascript)
fn run(
  term: terminal.Terminal(bs),
  m: Model,
) -> promise.Promise(terminal.Terminal(bs)) {
  case
    terminal.draw(term, fn(frame) {
      terminal.with_buffer(frame, render(m, frame.area))
    })
  {
    Error(_) -> promise.resolve(term)
    Ok(drawn) ->
      promise.await(terminal.poll(drawn, 60), fn(result) {
        case result {
          Error(_) -> promise.resolve(drawn)
          Ok(#(event, polled)) -> {
            let next = update(event, m)
            case next.quit {
              True -> promise.resolve(polled)
              False -> run(polled, next)
            }
          }
        }
      })
  }
}
