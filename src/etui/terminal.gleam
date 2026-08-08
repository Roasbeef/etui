/// Drive rendering from your own loop.
///
/// `etui/app` owns the loop for you: you hand it a render function and an
/// event handler and it never gives control back. That is the right shape for
/// most apps and the wrong shape as soon as the terminal is not the only thing
/// your program is doing, because there is nowhere to put the rest. A supervised
/// OTP application, a program already driving a socket, a test that wants to
/// step one frame at a time: all of them need the loop to be theirs.
///
/// A `Terminal` is the piece `app` was hiding. You open it, draw frames when
/// you want to, poll for input when you want to, and close it:
///
/// ```gleam
/// let assert Ok(term) = terminal.new(default.new())
/// let term = case terminal.draw(term, fn(frame) {
///   frame |> terminal.draw_widget(frame.area, my_widget)
/// }) {
///   Ok(t) -> t
///   Error(_) -> term
/// }
/// let assert Ok(#(event, term)) = terminal.poll(term, 16)
/// terminal.restore(term)
/// ```
///
/// Diffing, first-frame handling and resize are still taken care of: `draw`
/// emits only the cells that changed since the last frame, and `poll` notices a
/// resize and arranges for the next `draw` to repaint everything.
///
/// The one thing it does not do is guarantee the terminal is restored if your
/// code panics. `app.run_buffered` and friends wrap the loop in a `try/after`
/// for that; if you drive the terminal yourself, restoring it is yours to
/// arrange.
import etui/backend.{type InputEvent, type RenderOp}
import etui/buffer
import etui/cursor
import etui/geometry.{type Position, type Rect}
import etui/widget

@target(javascript)
import gleam/javascript/promise

// ─────────────────────────────────────────────────────────────────
// Frame

/// Where the hardware cursor should be after a frame is drawn.
pub type Cursor {
  /// Leave the cursor wherever it was. The default, and what a full-screen
  /// app wants: it hides the cursor once at start-up and never thinks about
  /// it again.
  CursorUntouched
  /// Hide the cursor for this frame.
  CursorHidden
  /// Show the cursor at a 0-based cell position. Text inputs want this so the
  /// insertion point is where the terminal actually blinks.
  CursorShown(Position)
}

/// One frame under construction: the area it covers, the cells drawn into it
/// so far, and where the cursor should end up.
pub type Frame {
  Frame(area: Rect, buffer: buffer.Buffer, cursor: Cursor)
}

/// Draw a widget into part of the frame.
pub fn draw_widget(frame: Frame, area: Rect, w: widget.Widget) -> Frame {
  Frame(..frame, buffer: w(frame.buffer, area))
}

/// Replace the frame's buffer, for code that renders by returning a buffer
/// rather than by applying widgets.
pub fn with_buffer(frame: Frame, buf: buffer.Buffer) -> Frame {
  Frame(..frame, buffer: buf)
}

/// Put the cursor at `pos` when this frame is drawn.
pub fn set_cursor(frame: Frame, pos: Position) -> Frame {
  Frame(..frame, cursor: CursorShown(pos))
}

/// Hide the cursor when this frame is drawn.
pub fn hide_cursor(frame: Frame) -> Frame {
  Frame(..frame, cursor: CursorHidden)
}

// ─────────────────────────────────────────────────────────────────
// Frame assembly, shared by both targets and by etui/app

/// The render ops that take the terminal from `prev` to `curr`.
///
/// A first frame, at start-up or after a resize, repaints everything: what the
/// terminal is showing is unknown, so there is nothing to diff against. Every
/// frame after that emits only the cells that changed.
pub fn frame_ops(
  prev: buffer.Buffer,
  curr: buffer.Buffer,
  first_frame: Bool,
  cur: Cursor,
) -> List(RenderOp) {
  let ansi = case first_frame {
    True -> buffer.to_ansi(curr)
    False -> buffer.diff_to_ansi(prev, curr)
  }
  let cursor_ansi = case cur {
    CursorUntouched -> ""
    CursorHidden -> cursor.hide()
    CursorShown(pos) ->
      cursor.hide() <> cursor.move_to(pos.y + 1, pos.x + 1) <> cursor.show()
  }
  case ansi, cursor_ansi {
    "", "" -> []
    "", only_cursor -> [backend.Write(only_cursor)]
    _, _ ->
      case first_frame {
        True -> [
          backend.ClearScreen,
          backend.MoveCursor(0, 0),
          backend.Write(ansi <> cursor_ansi),
        ]
        False -> [backend.Write(ansi <> cursor_ansi)]
      }
  }
}

fn blank_screen(width: Int, height: Int) -> buffer.Buffer {
  buffer.buffer_new(geometry.rect_new(0, 0, width, height))
}

// ─────────────────────────────────────────────────────────────────
// Erlang

@target(erlang)
/// An open terminal: the backend, its state, and what was last drawn.
pub opaque type Terminal(backend_state) {
  Terminal(
    backend: backend.Backend(backend_state),
    state: backend_state,
    /// What the terminal is currently showing, to diff the next frame against.
    previous: buffer.Buffer,
    /// Set at start-up and after a resize: the next frame repaints in full.
    repaint: Bool,
  )
}

@target(erlang)
/// Open a terminal: enter raw mode and the alternate screen, hide the cursor,
/// and measure the screen.
pub fn new(
  b: backend.Backend(backend_state),
) -> Result(Terminal(backend_state), backend.Error) {
  case b.init() {
    Ok(bs) -> {
      let _ = b.render(bs, [backend.Write(cursor.hide())])
      let #(size, bs2) = case b.next_size(bs) {
        Ok(#(sz, bs1)) -> #(sz, bs1)
        _ -> #(backend.TerminalSize(width: 80, height: 24), bs)
      }
      Ok(Terminal(
        backend: b,
        state: bs2,
        previous: blank_screen(size.width, size.height),
        repaint: True,
      ))
    }
    Error(e) -> Error(e)
  }
}

@target(erlang)
/// The screen area, which is what a frame will be given.
pub fn area(term: Terminal(backend_state)) -> Rect {
  buffer.area(term.previous)
}

@target(erlang)
/// Draw one frame. `build` is handed an empty frame the size of the screen and
/// returns it filled in.
pub fn draw(
  term: Terminal(backend_state),
  build: fn(Frame) -> Frame,
) -> Result(Terminal(backend_state), backend.Error) {
  let screen = area(term)
  let frame =
    build(Frame(
      area: screen,
      buffer: buffer.buffer_new(screen),
      cursor: CursorUntouched,
    ))
  let ops = frame_ops(term.previous, frame.buffer, term.repaint, frame.cursor)
  case term.backend.render(term.state, ops) {
    Ok(bs) ->
      Ok(Terminal(..term, state: bs, previous: frame.buffer, repaint: False))
    Error(e) -> Error(e)
  }
}

@target(erlang)
/// Wait up to `timeout_ms` for an event.
///
/// A resize is reported like any other event, and also resets the terminal's
/// idea of what is on screen, so the next `draw` repaints at the new size.
pub fn poll(
  term: Terminal(backend_state),
  timeout_ms: Int,
) -> Result(#(InputEvent, Terminal(backend_state)), backend.Error) {
  case term.backend.poll(term.state, timeout_ms) {
    Ok(#(event, bs)) -> Ok(#(event, absorb(Terminal(..term, state: bs), event)))
    Error(e) -> Error(e)
  }
}

@target(erlang)
/// Leave the alternate screen, restore the cursor and hand the terminal back.
pub fn restore(term: Terminal(backend_state)) -> Nil {
  let _ = term.backend.render(term.state, [backend.Write(cursor.show())])
  term.backend.cleanup(term.state)
}

// ─────────────────────────────────────────────────────────────────
// JavaScript
//
// Same shape; only `poll` differs, because the Node and browser backends read
// input asynchronously.

@target(javascript)
pub opaque type Terminal(backend_state) {
  Terminal(
    backend: backend.AsyncBackend(backend_state),
    state: backend_state,
    previous: buffer.Buffer,
    repaint: Bool,
  )
}

@target(javascript)
pub fn new(
  b: backend.AsyncBackend(backend_state),
) -> Result(Terminal(backend_state), backend.Error) {
  case b.init() {
    Ok(bs) -> {
      let _ = b.render(bs, [backend.Write(cursor.hide())])
      let #(size, bs2) = case b.next_size(bs) {
        Ok(#(sz, bs1)) -> #(sz, bs1)
        _ -> #(backend.TerminalSize(width: 80, height: 24), bs)
      }
      Ok(Terminal(
        backend: b,
        state: bs2,
        previous: blank_screen(size.width, size.height),
        repaint: True,
      ))
    }
    Error(e) -> Error(e)
  }
}

@target(javascript)
pub fn area(term: Terminal(backend_state)) -> Rect {
  buffer.area(term.previous)
}

@target(javascript)
pub fn draw(
  term: Terminal(backend_state),
  build: fn(Frame) -> Frame,
) -> Result(Terminal(backend_state), backend.Error) {
  let screen = area(term)
  let frame =
    build(Frame(
      area: screen,
      buffer: buffer.buffer_new(screen),
      cursor: CursorUntouched,
    ))
  let ops = frame_ops(term.previous, frame.buffer, term.repaint, frame.cursor)
  case term.backend.render(term.state, ops) {
    Ok(bs) ->
      Ok(Terminal(..term, state: bs, previous: frame.buffer, repaint: False))
    Error(e) -> Error(e)
  }
}

@target(javascript)
pub fn poll(
  term: Terminal(backend_state),
  timeout_ms: Int,
) -> promise.Promise(
  Result(#(InputEvent, Terminal(backend_state)), backend.Error),
) {
  promise.map(term.backend.poll(term.state, timeout_ms), fn(result) {
    case result {
      Ok(#(event, bs)) ->
        Ok(#(event, absorb(Terminal(..term, state: bs), event)))
      Error(e) -> Error(e)
    }
  })
}

@target(javascript)
pub fn restore(term: Terminal(backend_state)) -> Nil {
  let _ = term.backend.render(term.state, [backend.Write(cursor.show())])
  term.backend.cleanup(term.state)
}

// A resize invalidates everything we knew about the screen.
fn absorb(
  term: Terminal(backend_state),
  event: InputEvent,
) -> Terminal(backend_state) {
  case event {
    backend.Resize(w, h) ->
      Terminal(..term, previous: blank_screen(w, h), repaint: True)
    _ -> term
  }
}
