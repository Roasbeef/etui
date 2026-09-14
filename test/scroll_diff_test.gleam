//// Scroll candidates are speculative; the emitted terminal state is exact.
//// These fixtures also feed dev/scroll_screen_test.mjs, which applies both
//// render paths to xterm and compares cells, rendition and cursor position.

import etui/backend
import etui/buffer
import etui/geometry.{Position, rect_new}
import etui/style
import etui/terminal
import gleam/int
import gleam/list
import gleam/string
import gleeunit/should

/// A full screen with fixed header, footer, and an optional static sidebar.
/// Rows contain different text so the detector cannot mistake blank padding
/// for useful movement. Both scroll directions and newly exposed rows vary.
pub fn fixture(offset: Int, sidebar: Int) -> buffer.Buffer {
  list.fold(
    list.index_map(list.repeat(Nil, 24), fn(_, i) { i }),
    buffer.buffer_new(rect_new(0, 0, 80, 24)),
    fn(b, y) {
      let row = case y {
        0 | 1 | 22 | 23 -> y + 1000
        _ -> y + offset
      }
      let text =
        string.repeat(string.slice("ABCDEFGHIJKLMNOPQRSTUVW", row % 23, 1), 80)
      let b = buffer.set_string(b, Position(0, y), text, style.default_style())
      case sidebar {
        0 -> b
        _ ->
          buffer.set_string(
            b,
            Position(sidebar, y),
            "fixed " <> int.to_string(y),
            style.default_style(),
          )
      }
    },
  )
}

pub fn a_one_row_scroll_repaints_only_the_exposed_row_test() {
  let before = fixture(0, 0)
  let after = fixture(1, 0)
  let ansi = buffer.diff_fullscreen_to_ansi(before, after)
  string.contains(ansi, "\u{001B}[3;22r\u{001B}[1S") |> should.be_true
  string.contains(ansi, "\u{001B}[r") |> should.be_true
  should.be_true(
    string.byte_size(ansi)
    < string.byte_size(buffer.diff_to_ansi(before, after)) / 4,
  )
}

pub fn upward_reading_scrolls_down_inside_the_transcript_test() {
  let before = fixture(3, 0)
  let after = fixture(0, 0)
  buffer.diff_fullscreen_to_ansi(before, after)
  |> string.contains("\u{001B}[3;22r\u{001B}[3T")
  |> should.be_true
}

pub fn a_fixed_sidebar_is_repaired_after_the_scroll_test() {
  let before = fixture(0, 60)
  let after = fixture(1, 60)
  let ansi = buffer.diff_fullscreen_to_ansi(before, after)
  string.contains(ansi, "\u{001B}[1S") |> should.be_true
  should.be_true(
    string.byte_size(ansi)
    < string.byte_size(buffer.diff_to_ansi(before, after)),
  )
}

pub fn a_small_change_keeps_the_cell_diff_test() {
  let before = fixture(0, 0)
  let after =
    buffer.set_string(before, Position(3, 10), "edit", style.default_style())
  buffer.diff_fullscreen_to_ansi(before, after)
  |> should.equal(buffer.diff_to_ansi(before, after))
}

pub fn identical_frames_still_emit_nothing_test() {
  let frame = fixture(0, 0)
  buffer.diff_fullscreen_to_ansi(frame, frame) |> should.equal("")
}

pub fn inline_and_fixed_viewports_do_not_emit_scroll_commands_test() {
  let before = fixture(0, 0)
  let after = fixture(1, 0)
  let ansi =
    terminal.frame_ops(before, after, False, terminal.CursorUntouched, False)
    |> backend.ops_to_ansi
  string.contains(ansi, "\u{001B}[1S") |> should.be_false
  string.contains(ansi, "\u{001B}[3;22r") |> should.be_false
}

pub fn resize_uses_the_ordinary_diff_test() {
  let before = fixture(0, 0)
  let after = buffer.buffer_new(rect_new(0, 0, 40, 12))
  buffer.diff_fullscreen_to_ansi(before, after)
  |> should.equal(buffer.diff_to_ansi(before, after))
}

pub fn offset_buffers_use_the_ordinary_diff_test() {
  let before =
    buffer.buffer_new_filled(
      rect_new(2, 3, 80, 24),
      "old content",
      style.default_style(),
    )
  let after =
    buffer.buffer_new_filled(
      rect_new(2, 3, 80, 24),
      "new content",
      style.default_style(),
    )
  buffer.diff_fullscreen_to_ansi(before, after)
  |> should.equal(buffer.diff_to_ansi(before, after))
}
