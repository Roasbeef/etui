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
import etui/geometry.{Position}
import etui/style
import etui/text
import etui_lab
import etui_lab_inline
import etui_showcase
import gleam/int
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

// ─────────────────────────────────────────────────────────────────
// The 2.0 bench
//
// etui_lab drives its own loop over etui/terminal, so its render is a plain
// function and can be checked the same way. These pin the two screens whose
// correctness is a matter of exact cell positions.

fn lab_frame(key: String, width: Int, height: Int) -> buffer.Buffer {
  let model = etui_lab.update(backend.KeyPress(key), etui_lab.initial())
  let #(buf, _settled, _panes) =
    etui_lab.render(model, geometry.rect_new(0, 0, width, height))
  buf
}

pub fn the_six_flex_modes_are_all_different_test() {
  // If two modes ever render identically, one of them is not doing its job.
  let buf = lab_frame("1", 92, 22)
  let strips =
    indices(6)
    |> list.map(fn(i) { row_text(buf, i + 5, 92) })
  list.length(list.unique(strips))
  |> should.equal(6)
}

pub fn flex_start_packs_left_and_flex_end_packs_right_test() {
  let buf = lab_frame("1", 92, 22)
  let start = row_text(buf, 5, 92)
  let end = row_text(buf, 6, 92)
  string.contains(string.slice(start, 14, 20), "██████")
  |> should.equal(True)
  string.contains(string.slice(end, 14, 20), "██████")
  |> should.equal(False)
}

pub fn the_weighted_columns_hold_their_ratio_test() {
  // Three columns weighted 3:1:1 across 92 cells.
  let buf = lab_frame("1", 92, 22)
  let row = row_text(buf, 14, 92)
  string.contains(row, "w=3 width=56")
  |> should.equal(True)
  string.contains(row, "w=1 width=18")
  |> should.equal(True)
}

pub fn the_scroll_screen_reports_the_rows_it_was_given_test() {
  // The state panel prints the height the list was actually laid out with,
  // which is read back from the layout rather than guessed from the screen.
  let buf = lab_frame("4", 92, 22)
  string.contains(row_text(buf, 8, 92), "rows      14")
  |> should.equal(True)
}

pub fn every_lab_screen_fills_its_width_test() {
  list.each(["1", "2", "3", "4", "5", "6", "7"], fn(key) {
    list.each([#(80, 24), #(120, 32)], fn(size) {
      let #(width, height) = size
      let buf = lab_frame(key, width, height)
      list.each(indices(height), fn(y) {
        #(key, y, text.cell_width(row_text(buf, y, width)))
        |> should.equal(#(key, y, width))
      })
    })
  })
}

pub fn the_text_screen_keeps_words_whole_across_styles_test() {
  // "etui.log" and the comma after it come from different spans with no space
  // between them, so they are one word. An earlier wrapper split each span on
  // spaces and rejoined with spaces, inventing a space and pushing the comma
  // onto the next row.
  let buf = lab_frame("5", 96, 28)
  let joined =
    indices(4)
    |> list.map(fn(i) { row_text(buf, i + 6, 40) })
    |> string.join(" ")
  string.contains(joined, "etui.log,")
  |> should.equal(True)
}

// The UNDER screen is a claim about colour, and colour is exactly what
// row_text throws away, so these read the cells.

fn cell_at(buf: buffer.Buffer, x: Int, y: Int) -> buffer.Cell {
  buffer.get_cell(buf, Position(x, y))
}

pub fn the_underline_screen_colours_the_line_not_the_text_test() {
  let buf = lab_frame("6", 80, 24)
  // First sample row, inside the sample column.
  let sample = cell_at(buf, 18, 6)

  buffer.cell_underline_color(sample) |> should.equal(style.Indexed(9))
  style.has(buffer.cell_modifier(sample), style.underline())
  |> should.equal(True)
  // The text itself stays the terminal's colour: only the line is red.
  buffer.cell_fg(sample) |> should.equal(style.Default)
}

pub fn the_underline_screen_control_row_asks_but_does_not_underline_test() {
  // The row that proves a colour alone draws nothing: same colour asked for,
  // no underline bit. A terminal showing a line here would be inventing one.
  let control = cell_at(lab_frame("6", 80, 24), 18, 9)

  buffer.cell_underline_color(control) |> should.equal(style.Indexed(9))
  style.has(buffer.cell_modifier(control), style.underline())
  |> should.equal(False)
}

pub fn the_underline_screen_labels_stay_uncoloured_test() {
  // The label column is drawn with a different style in the same row, so this
  // catches a style that leaked across a span boundary.
  let label = cell_at(lab_frame("6", 80, 24), 0, 6)
  buffer.cell_underline_color(label) |> should.equal(style.Default)
}

/// The end of the path, in bytes: what the lab hands the terminal for the
/// UNDER screen carries the sequences, and the screen that asks for no
/// underline colour carries none. Cell assertions above stop one step short
/// of this.
pub fn the_underline_screen_emits_sgr_58_test() {
  let under = buffer.to_ansi(lab_frame("6", 80, 24))
  string.contains(under, "\u{001B}[58;5;9m") |> should.equal(True)
  string.contains(under, "\u{001B}[58;5;2m") |> should.equal(True)

  let styles = buffer.to_ansi(lab_frame("2", 80, 24))
  string.contains(styles, "58;") |> should.equal(False)
}

pub fn the_text_screen_carries_the_squiggle_through_a_reflow_test() {
  // "rotatting" is underlined in red inside an otherwise plain line. Narrow
  // the column and it moves, and may split; every cell of it must keep the
  // colour, because the colour belongs to the word.
  let squiggle_cells = fn(model: etui_lab.Model) {
    let #(buf, _, _) = etui_lab.render(model, geometry.rect_new(0, 0, 96, 28))
    // Only the wrapped column. The screen draws the same line a second time
    // unwrapped, beside it, which would count the word twice.
    let column = int.min(model.prose_width, 96 / 2 - 3)
    indices(28)
    |> list.flat_map(fn(y) {
      indices(column)
      |> list.map(fn(x) { buffer.get_cell(buf, Position(x, y)) })
    })
    |> list.filter(fn(c) {
      style.has(buffer.cell_modifier(c), style.underline())
      && buffer.cell_underline_color(c) == style.Rgb(220, 60, 60)
    })
  }

  let wide = etui_lab.update(backend.KeyPress("5"), etui_lab.initial())
  let narrow =
    list.fold(indices(6), wide, fn(m, _) {
      etui_lab.update(backend.KeyPress("left"), m)
    })

  // Nine letters, whatever the column width does to where they sit.
  #("wide", list.length(squiggle_cells(wide))) |> should.equal(#("wide", 9))
  #("narrow", list.length(squiggle_cells(narrow)))
  |> should.equal(#("narrow", 9))
}

/// The EXIT screen is a promise about bytes, so it has to name the bytes the
/// library actually sends. A sequence renamed in `backend.restore_ops` and
/// not here would leave the lab telling the reader something untrue.
pub fn the_exit_screen_lists_what_is_really_sent_test() {
  let buf = lab_frame("7", 96, 28)
  let shown =
    indices(10)
    |> list.map(fn(i) { row_text(buf, i + 4, 96) })
    |> string.join(" ")
  let restore = backend.restore_sequence()

  list.each(["?1000l", "?2004l", "?1049l", "?7h", "?25h"], fn(seq) {
    #(seq, string.contains(shown, seq)) |> should.equal(#(seq, True))
    #(seq, string.contains(restore, "\u{001B}[" <> seq))
    |> should.equal(#(seq, True))
  })
}

pub fn the_exit_screen_names_all_three_endings_test() {
  let buf = lab_frame("7", 96, 28)
  let shown =
    indices(8)
    |> list.map(fn(i) { row_text(buf, i + 13, 96) })
    |> string.join(" ")

  string.contains(shown, "kill -9") |> should.equal(True)
  string.contains(shown, "kill -INT") |> should.equal(True)
  // The flag without which an external SIGINT is the VM's, not ours.
  string.contains(shown, "ERL_FLAGS=+B") |> should.equal(True)
}

pub fn the_text_screen_expands_tabs_test() {
  let buf = lab_frame("5", 96, 28)
  string.contains(row_text(buf, 18, 96), "cells=17")
  |> should.equal(True)
}

// ─────────────────────────────────────────────────────────────────
// The inline bench
//
// An inline viewport cannot be shown from inside a full-screen app, so it has
// its own entry point. Its renderer is still a plain function.

pub fn the_inline_panel_fits_its_six_rows_test() {
  // The panel is drawn into the bottom rows of the terminal, so its area does
  // not start at the origin. Every row still has to fill its width.
  let area = geometry.rect_new(0, 18, 70, etui_lab_inline.rows)
  let buf = etui_lab_inline.render(etui_lab_inline.initial(), area)
  list.each(indices(etui_lab_inline.rows), fn(i) {
    let y = 18 + i
    #(y, text.cell_width(row_text_at(buf, y, 0, 70)))
    |> should.equal(#(y, 70))
  })
}

pub fn the_inline_panel_shows_its_progress_test() {
  let area = geometry.rect_new(0, 18, 70, etui_lab_inline.rows)
  let advanced =
    list.fold(indices(7), etui_lab_inline.initial(), fn(m, _) {
      etui_lab_inline.update(backend.Tick, m)
    })
  string.contains(
    row_text_at(etui_lab_inline.render(advanced, area), 19, 0, 70),
    "7%",
  )
  |> should.equal(True)
}

fn row_text_at(buf: buffer.Buffer, y: Int, x0: Int, width: Int) -> String {
  indices(width)
  |> list.map(fn(i) {
    let cell = buffer.get_cell(buf, Position(x0 + i, y))
    case buffer.is_continuation(cell) {
      True -> ""
      False -> buffer.cell_symbol(cell)
    }
  })
  |> string.concat
}

pub fn the_input_screen_decodes_modified_keys_test() {
  // The raw string and what keys.parse makes of it, side by side. The second
  // is what a case expression should be matching on, so the bench shows it.
  let model =
    etui_lab.initial()
    |> etui_lab.update(backend.KeyPress("3"), _)
    |> etui_lab.update(backend.KeyPress("ctrl+shift+left"), _)
  let #(buf, _settled, _panes) =
    etui_lab.render(model, geometry.rect_new(0, 0, 96, 22))
  string.contains(row_text(buf, 6, 60), "Left + ctrl,shift")
  |> should.equal(True)
}
