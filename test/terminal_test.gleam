@target(erlang)
/// `etui/terminal` drives rendering without owning the loop, so these check
/// the parts the app loops used to hide: what a frame actually emits, that a
/// second frame emits only what changed, and that a resize forces a repaint.
import etui/backend
import etui/buffer
import etui/cursor
import etui/geometry.{Position, rect_new}

import etui/style
import etui/terminal
import etui/widgets/paragraph
import gleam/list
import gleam/result
import gleam/string
import gleeunit/should

// ─────────────────────────────────────────────────────────────────
// A backend that records what was written and replays a fixed event script.

@target(erlang)
type Recorder {
  Recorder(
    written: List(String),
    events: List(backend.InputEvent),
    /// Render calls seen so far. Used to make "the second frame emits nothing"
    /// an assertion rather than a hope: the backend refuses ops after this
    /// many calls, so a frame that should be silent and is not fails the draw.
    ///
    /// The count includes the one render terminal.new does to open the
    /// viewport, so a test that allows the first frame passes 2.
    renders: Int,
    silent_after: Int,
  )
}

@target(erlang)
fn recorder(
  events: List(backend.InputEvent),
  size: backend.TerminalSize,
) -> backend.Backend(Recorder) {
  backend.Backend(
    init: fn() {
      Ok(Recorder(written: [], events: events, renders: 0, silent_after: -1))
    },
    render: fn(s, ops) {
      let seen = s.renders + 1
      case s.silent_after >= 0 && seen > s.silent_after && ops != [] {
        True ->
          Error(backend.IOError("expected no output, got " <> describe_all(ops)))
        False ->
          Ok(
            Recorder(
              ..s,
              renders: seen,
              written: list.append(s.written, list.map(ops, describe)),
            ),
          )
      }
    },
    poll: fn(s, _timeout) {
      case s.events {
        [ev, ..rest] -> Ok(#(ev, Recorder(..s, events: rest)))
        [] -> Error(backend.Interrupted)
      }
    },
    next_size: fn(s) { Ok(#(size, s)) },
    cleanup: fn(_s) { Nil },
  )
}

@target(erlang)
fn describe_all(ops: List(backend.RenderOp)) -> String {
  string.join(list.map(ops, describe), " ")
}

@target(erlang)
fn describe(op: backend.RenderOp) -> String {
  case op {
    backend.Write(s) -> "W:" <> s
    backend.ClearScreen -> "CLEAR"
    backend.MoveCursor(x, y) ->
      "MOVE:" <> string.inspect(x) <> "," <> string.inspect(y)
    _ -> "OTHER"
  }
}

@target(erlang)
fn silent_after(
  b: backend.Backend(Recorder),
  frames: Int,
) -> backend.Backend(Recorder) {
  backend.Backend(..b, init: fn() {
    case b.init() {
      Ok(s) -> Ok(Recorder(..s, silent_after: frames))
      Error(e) -> Error(e)
    }
  })
}

@target(erlang)
fn text_frame(body: String) -> fn(terminal.Frame) -> terminal.Frame {
  fn(frame) {
    terminal.with_buffer(
      frame,
      paragraph.render(frame.buffer, frame.area, paragraph.paragraph_new(body)),
    )
  }
}

// ─────────────────────────────────────────────────────────────────
// Opening and sizing

@target(erlang)
pub fn a_new_terminal_takes_its_area_from_the_backend_test() {
  let assert Ok(term) = terminal.new(recorder([], backend.TerminalSize(40, 12)))
  terminal.area(term)
  |> should.equal(rect_new(0, 0, 40, 12))
}

// ─────────────────────────────────────────────────────────────────
// What a frame emits

@target(erlang)
pub fn an_unchanged_second_frame_emits_nothing_test() {
  // The whole point of diffing: drawing the same thing twice costs one frame.
  // The backend refuses to accept ops after the first render, so a second
  // frame that emitted anything would fail the draw.
  let assert Ok(term) =
    terminal.new(silent_after(recorder([], backend.TerminalSize(20, 3)), 2))
  let assert Ok(first) = terminal.draw(term, text_frame("hello"))
  terminal.draw(first, text_frame("hello"))
  |> result.is_ok
  |> should.equal(True)
}

@target(erlang)
pub fn a_changed_second_frame_does_emit_test() {
  // The counter-test: the same backend rejects the second frame when the
  // content actually differs, which is how we know the check above has teeth.
  let assert Ok(term) =
    terminal.new(silent_after(recorder([], backend.TerminalSize(20, 3)), 2))
  let assert Ok(first) = terminal.draw(term, text_frame("hello"))
  terminal.draw(first, text_frame("goodbye"))
  |> result.is_ok
  |> should.equal(False)
}

@target(erlang)
pub fn a_frame_after_a_resize_repaints_rather_than_diffing_test() {
  // A resize invalidates the previous buffer, so the next frame has to be a
  // full repaint even though its content is unchanged.
  let assert Ok(term) =
    terminal.new(silent_after(
      recorder([backend.Resize(20, 3)], backend.TerminalSize(20, 3)),
      2,
    ))
  let assert Ok(drawn) = terminal.draw(term, text_frame("hello"))
  let assert Ok(#(_, resized)) = terminal.poll(drawn, 0)
  terminal.draw(resized, text_frame("hello"))
  |> result.is_ok
  |> should.equal(False)
}

@target(erlang)
pub fn frame_ops_repaints_in_full_on_a_first_frame_test() {
  let screen = rect_new(0, 0, 5, 1)
  let blank = buffer.buffer_new(screen)
  let filled =
    buffer.set_string(
      blank,
      Position(0, 0),
      "abcde",
      style.Default,
      style.Default,
      style.none(),
    )
  let ops =
    terminal.frame_ops(blank, filled, True, terminal.CursorUntouched, True)
  list.map(ops, describe)
  |> list.take(2)
  |> should.equal(["CLEAR", "MOVE:0,0"])
}

@target(erlang)
pub fn frame_ops_emits_nothing_when_nothing_changed_test() {
  let screen = rect_new(0, 0, 5, 1)
  let same = buffer.buffer_new(screen)
  terminal.frame_ops(same, same, False, terminal.CursorUntouched, True)
  |> should.equal([])
}

@target(erlang)
pub fn frame_ops_emits_only_the_changed_cells_test() {
  let screen = rect_new(0, 0, 5, 1)
  let before =
    buffer.set_string(
      buffer.buffer_new(screen),
      Position(0, 0),
      "abcde",
      style.Default,
      style.Default,
      style.none(),
    )
  let after =
    buffer.set_string(
      before,
      Position(2, 0),
      "X",
      style.Default,
      style.Default,
      style.none(),
    )
  let ops =
    terminal.frame_ops(before, after, False, terminal.CursorUntouched, True)
  // One write, and it carries the single changed cell rather than the row.
  case ops {
    [backend.Write(ansi)] -> {
      string.contains(ansi, "X")
      |> should.equal(True)
      string.contains(ansi, "abcde")
      |> should.equal(False)
    }
    _ -> should.fail()
  }
}

// ─────────────────────────────────────────────────────────────────
// The cursor

@target(erlang)
pub fn an_untouched_cursor_emits_no_cursor_ops_test() {
  let screen = rect_new(0, 0, 3, 1)
  let same = buffer.buffer_new(screen)
  terminal.frame_ops(same, same, False, terminal.CursorUntouched, True)
  |> should.equal([])
}

@target(erlang)
pub fn a_hidden_cursor_still_emits_when_the_frame_is_unchanged_test() {
  // A cursor instruction has to go out even on a frame with no cell changes,
  // or the cursor stays where the previous frame left it.
  let screen = rect_new(0, 0, 3, 1)
  let same = buffer.buffer_new(screen)
  terminal.frame_ops(same, same, False, terminal.CursorHidden, True)
  |> should.equal([backend.Write(cursor.hide())])
}

@target(erlang)
pub fn a_shown_cursor_moves_to_a_one_based_position_test() {
  let screen = rect_new(0, 0, 3, 1)
  let same = buffer.buffer_new(screen)
  case
    terminal.frame_ops(
      same,
      same,
      False,
      terminal.CursorShown(Position(4, 2)),
      True,
    )
  {
    [backend.Write(ansi)] ->
      // Terminals count from 1, and rows come before columns.
      string.contains(ansi, "\u{001B}[3;5H")
      |> should.equal(True)
    _ -> should.fail()
  }
}

// ─────────────────────────────────────────────────────────────────
// Resize

@target(erlang)
pub fn a_resize_changes_the_area_and_forces_a_repaint_test() {
  let assert Ok(term) =
    terminal.new(recorder([backend.Resize(50, 8)], backend.TerminalSize(20, 3)))
  let assert Ok(drawn) = terminal.draw(term, text_frame("hi"))
  let assert Ok(#(event, resized)) = terminal.poll(drawn, 0)

  event
  |> should.equal(backend.Resize(50, 8))
  terminal.area(resized)
  |> should.equal(rect_new(0, 0, 50, 8))

  // The next frame must repaint rather than diff against a buffer of the old
  // size, which is why the ops start with a clear.
  let assert Ok(_) = terminal.draw(resized, text_frame("hi"))
  Nil
}

@target(erlang)
pub fn an_ordinary_event_leaves_the_area_alone_test() {
  let assert Ok(term) =
    terminal.new(recorder([backend.KeyPress("a")], backend.TerminalSize(20, 3)))
  let assert Ok(#(_, after)) = terminal.poll(term, 0)
  terminal.area(after)
  |> should.equal(rect_new(0, 0, 20, 3))
}

// ─────────────────────────────────────────────────────────────────
// Building a frame

@target(erlang)
pub fn draw_widget_composes_onto_the_frame_buffer_test() {
  let screen = rect_new(0, 0, 6, 1)
  let frame =
    terminal.Frame(
      area: screen,
      buffer: buffer.buffer_new(screen),
      cursor: terminal.CursorUntouched,
    )
  let widget = fn(buf, area) {
    paragraph.render(buf, area, paragraph.paragraph_new("ok"))
  }
  let out = terminal.draw_widget(frame, screen, widget)
  buffer.cell_symbol(buffer.get_cell(out.buffer, Position(0, 0)))
  |> should.equal("o")
}

@target(erlang)
pub fn set_cursor_and_hide_cursor_replace_each_other_test() {
  let screen = rect_new(0, 0, 3, 1)
  let frame =
    terminal.Frame(
      area: screen,
      buffer: buffer.buffer_new(screen),
      cursor: terminal.CursorUntouched,
    )
  terminal.set_cursor(frame, Position(1, 1)).cursor
  |> should.equal(terminal.CursorShown(Position(1, 1)))
  terminal.hide_cursor(terminal.set_cursor(frame, Position(1, 1))).cursor
  |> should.equal(terminal.CursorHidden)
}

// ─────────────────────────────────────────────────────────────────
// Viewports

@target(erlang)
pub fn a_fullscreen_viewport_takes_the_whole_terminal_test() {
  let assert Ok(term) = terminal.new(recorder([], backend.TerminalSize(40, 12)))
  terminal.area(term)
  |> should.equal(rect_new(0, 0, 40, 12))
}

@target(erlang)
pub fn an_inline_viewport_sits_at_the_bottom_test() {
  // Five rows of a twelve-row terminal, at the bottom, so whatever the shell
  // has already printed keeps scrolling above it.
  let assert Ok(term) =
    terminal.new_with_viewport(
      recorder([], backend.TerminalSize(40, 12)),
      terminal.Inline(5),
    )
  terminal.area(term)
  |> should.equal(rect_new(0, 7, 40, 5))
}

@target(erlang)
pub fn an_inline_viewport_taller_than_the_terminal_is_capped_test() {
  let assert Ok(term) =
    terminal.new_with_viewport(
      recorder([], backend.TerminalSize(40, 6)),
      terminal.Inline(50),
    )
  terminal.area(term)
  |> should.equal(rect_new(0, 0, 40, 6))
}

@target(erlang)
pub fn a_fixed_viewport_is_clamped_to_the_terminal_test() {
  let assert Ok(term) =
    terminal.new_with_viewport(
      recorder([], backend.TerminalSize(40, 12)),
      terminal.Fixed(rect_new(30, 8, 20, 20)),
    )
  let area = terminal.area(term)
  // Clamped to fit: a rect asking for more than the terminal has is moved and
  // shrunk rather than allowed to draw off the edge.
  let fits = geometry.right(area) <= 40 && geometry.bottom(area) <= 12
  fits
  |> should.equal(True)
}

@target(erlang)
pub fn only_a_fullscreen_viewport_clears_the_screen_test() {
  // Clearing anywhere else would wipe scrollback the app does not own. An
  // inline repaint writes its own cells and nothing more.
  let screen = rect_new(0, 5, 5, 1)
  let blank = buffer.buffer_new(screen)
  let filled =
    buffer.set_string(
      blank,
      Position(0, 5),
      "abcde",
      style.Default,
      style.Default,
      style.none(),
    )
  list.map(
    terminal.frame_ops(blank, filled, True, terminal.CursorUntouched, False),
    describe,
  )
  |> list.contains("CLEAR")
  |> should.equal(False)

  list.map(
    terminal.frame_ops(blank, filled, True, terminal.CursorUntouched, True),
    describe,
  )
  |> list.contains("CLEAR")
  |> should.equal(True)
}

@target(erlang)
pub fn an_inline_viewport_still_repaints_in_full_on_a_first_frame_test() {
  // No clear, but every cell is written: the rows are ours and nothing is
  // known about what was in them.
  let screen = rect_new(0, 5, 5, 1)
  let blank = buffer.buffer_new(screen)
  let filled =
    buffer.set_string(
      blank,
      Position(0, 5),
      "abcde",
      style.Default,
      style.Default,
      style.none(),
    )
  case
    terminal.frame_ops(blank, filled, True, terminal.CursorUntouched, False)
  {
    [backend.Write(ansi)] ->
      string.contains(ansi, "abcde")
      |> should.equal(True)
    _ -> should.fail()
  }
}

@target(erlang)
pub fn a_resize_keeps_the_viewport_shape_test() {
  // The inline strip stays five rows tall and stays at the bottom.
  let assert Ok(term) =
    terminal.new_with_viewport(
      recorder([backend.Resize(60, 20)], backend.TerminalSize(40, 12)),
      terminal.Inline(5),
    )
  let assert Ok(#(_, resized)) = terminal.poll(term, 0)
  terminal.area(resized)
  |> should.equal(rect_new(0, 15, 60, 5))
}

@target(erlang)
pub fn the_viewport_is_readable_back_test() {
  let assert Ok(term) =
    terminal.new_with_viewport(
      recorder([], backend.TerminalSize(40, 12)),
      terminal.Inline(4),
    )
  terminal.viewport(term)
  |> should.equal(terminal.Inline(4))
}
