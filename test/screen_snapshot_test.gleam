/// Whole-screen tests: render a real app and look at the result.
///
/// The three worst bugs found in this codebase so far all lived between
/// components rather than inside one, and several hundred unit tests caught
/// none of them:
///
/// - a scrollbar drawn over a panel border, because it was positioned on the
///   border column and had nothing to say;
/// - two list panes scrolling together, because the focus that `h`/`l` set was
///   only ever read to colour a border;
/// - wide graphemes cut in half at a clip boundary, leaving a row that renders
///   one cell short and shifts everything after it.
///
/// Every one of them is visible in a rendered frame. These render frames from
/// `etui_showcase`, which is why that module exposes its model and renderer.
import etui/anim
import etui/backend
import etui/buffer
import etui/geometry.{type Rect, Position}
import etui/text
import etui_showcase
import gleam/list
import gleam/string
import gleeunit/should

// ─────────────────────────────────────────────────────────────────
// Rendering helpers

fn frame(tab_key: String, width: Int, height: Int) -> buffer.Buffer {
  let model =
    etui_showcase.update(
      backend.KeyPress(tab_key),
      etui_showcase.initial_model(),
    )
  etui_showcase.render(
    model,
    geometry.rect_new(0, 0, width, height),
    anim.anim_new(),
  )
}

fn indices(n: Int) -> List(Int) {
  case n <= 0 {
    True -> []
    False -> list.append(indices(n - 1), [n - 1])
  }
}

/// One row as it would reach the terminal: a wide grapheme contributes its
/// symbol, and the continuation cell that follows it contributes nothing,
/// exactly as `to_ansi` emits them.
fn row_text(buf: buffer.Buffer, y: Int, width: Int) -> String {
  indices(width)
  |> list.map(fn(x) {
    let cell = buffer.get_cell(buf, Position(x, y))
    case buffer.is_continuation(cell) {
      True -> ""
      False -> buffer.cell_symbol(cell)
    }
  })
  |> string.concat
}

fn every_tab(
  width: Int,
  height: Int,
  check: fn(String, buffer.Buffer) -> Nil,
) -> Nil {
  list.each(["f1", "f2", "f3", "f4", "f5"], fn(key) {
    check(key, frame(key, width, height))
  })
}

// ─────────────────────────────────────────────────────────────────
// Every row fills its width exactly

pub fn no_row_is_short_or_long_at_any_size_test() {
  // A row that measures less than the terminal width means something was
  // dropped: an orphan continuation cell renders as nothing and pulls the rest
  // of the line one column to the left. A row that measures more means a wide
  // grapheme was written where only one column was left.
  list.each([#(60, 20), #(96, 30), #(140, 40)], fn(size) {
    let #(width, height) = size
    every_tab(width, height, fn(key, buf) {
      list.each(indices(height), fn(y) {
        let measured = text.cell_width(row_text(buf, y, width))
        case measured == width {
          True -> Nil
          False -> {
            // Name the offending row rather than just failing on a number.
            #(key, y, measured)
            |> should.equal(#(key, y, width))
            Nil
          }
        }
      })
    })
  })
}

// ─────────────────────────────────────────────────────────────────
// Panel borders survive what is drawn over them

pub fn the_packages_panel_keeps_its_right_border_test() {
  // The scrollbar sits on this column. With fewer packages than visible rows
  // it has nothing to report, and drawing a full-height thumb there replaced
  // the rounded border with a solid block.
  let buf = frame("f2", 96, 30)
  let border_column = 37
  let interior =
    indices(18)
    |> list.map(fn(i) {
      buffer.cell_symbol(buffer.get_cell(buf, Position(border_column, i + 3)))
    })
  list.all(interior, fn(glyph) { glyph == "│" })
  |> should.equal(True)
}

pub fn a_panel_that_needs_a_scrollbar_still_gets_one_test() {
  // Shrunk until the fourteen packages no longer fit, the scrollbar reappears.
  let buf = frame("f2", 96, 14)
  let border_column = 37
  let glyphs =
    indices(6)
    |> list.map(fn(i) {
      buffer.cell_symbol(buffer.get_cell(buf, Position(border_column, i + 3)))
    })
  list.any(glyphs, fn(g) { g == "█" || g == "░" })
  |> should.equal(True)
}

// ─────────────────────────────────────────────────────────────────
// The frame reaches every edge

pub fn the_last_column_is_drawn_test() {
  // Auto-wrap used to make writing the bottom-right cell scroll the screen, so
  // the backend reserved a column and the status bar stopped one short.
  let buf = frame("f2", 96, 30)
  let last_row = row_text(buf, 29, 96)
  text.cell_width(last_row)
  |> should.equal(96)
  string.ends_with(last_row, " ")
  |> should.equal(True)
}

pub fn the_tab_bar_is_on_the_first_row_test() {
  let buf = frame("f1", 96, 30)
  row_text(buf, 0, 96)
  |> string.trim
  |> string.starts_with("FORM")
  |> should.equal(True)
}

// ─────────────────────────────────────────────────────────────────
// Focus actually moves something

pub fn arrows_move_only_the_focused_pane_test() {
  // h/l set a focus that was once read only to colour a border, so j/k moved
  // both panes at once and the two selections drifted apart at the ends.
  let base =
    etui_showcase.update(backend.KeyPress("f2"), etui_showcase.initial_model())
  let on_list = etui_showcase.update(backend.KeyPress("j"), base)
  let on_table =
    base
    |> etui_showcase.update(backend.KeyPress("l"), _)
    |> etui_showcase.update(backend.KeyPress("j"), _)

  let screen = geometry.rect_new(0, 0, 96, 30)
  let list_moved =
    etui_showcase.render(on_list, screen, anim.anim_new())
    != etui_showcase.render(base, screen, anim.anim_new())
  let table_moved =
    etui_showcase.render(on_table, screen, anim.anim_new())
    != etui_showcase.render(on_list, screen, anim.anim_new())

  list_moved
  |> should.equal(True)
  table_moved
  |> should.equal(True)
}

// ─────────────────────────────────────────────────────────────────
// A golden frame
//
// Structural checks say the frame is well formed; this says it is the frame we
// meant. It is deliberately one small screen: a change here should be read,
// not re-recorded out of habit.

pub fn the_tree_tab_renders_as_expected_test() {
  let buf = frame("f3", 60, 12)
  indices(12)
  |> list.map(fn(y) { row_text(buf, y, 60) })
  |> should.equal([
    " FORM │ LIST │ TREE │ LIVE │ ABOUT                          ",
    "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
    "╭ PROJECT TREE ──────────────────────────╮  ╭ SELECTION ──╮ ",
    "│▼ src/                                  │  │selected     │ ",
    "│  ▼ etui/                               │  │(none)       │ ",
    "│    ▶ backend/                          │  │             │ ",
    "│    ▼ widgets/                          │  │keys         │ ",
    "│        block.gleam                     │  │ ↵   expand/c│ ",
    "│        dialog.gleam                    │  │ j k   move s│ ",
    "╰────────────────────────────────────────╯  ╰─────────────╯ ",
    "                                                            ",
    " GATUI EXPLORER ● TREE jk nav  ↵ toggle  TAB switch  q quit ",
  ])
}
