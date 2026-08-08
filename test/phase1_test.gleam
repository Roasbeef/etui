/// Phase 1 of the ratatui-parity work: text normalisation, rect helpers,
/// and the buffer composition primitives (`blit`, `set_style`).
import etui/buffer
import etui/geometry.{type Rect, Margin, Position, Rect, Size}
import etui/style
import etui/text
import gleam/string
import gleeunit/should

// ─────────────────────────────────────────────────────────────────
// text: line-ending normalisation

pub fn wrap_strips_crlf_test() {
  // A \r left in the output occupies zero cells and desynchronises every
  // position after it.
  text.wrap("a\r\nb", 10)
  |> should.equal(["a", "b"])
}

pub fn wrap_treats_lone_cr_as_newline_test() {
  text.wrap("a\rb", 10)
  |> should.equal(["a", "b"])
}

pub fn normalise_newlines_leaves_clean_text_untouched_test() {
  text.normalise_newlines("a\nb")
  |> should.equal("a\nb")
}

// ─────────────────────────────────────────────────────────────────
// text: tab expansion

pub fn expand_tabs_advances_to_next_stop_test() {
  text.expand_tabs("a\tb", 4)
  |> should.equal("a   b")
}

pub fn expand_tabs_on_a_stop_boundary_emits_a_full_run_test() {
  text.expand_tabs("abcd\te", 4)
  |> should.equal("abcd    e")
}

pub fn expand_tabs_resets_column_on_newline_test() {
  text.expand_tabs("ab\n\tc", 4)
  |> should.equal("ab\n    c")
}

pub fn expand_tabs_counts_wide_graphemes_as_two_cells_test() {
  // 漢 is 2 cells, so the tab only needs 2 more to reach column 4.
  text.expand_tabs("漢\tx", 4)
  |> should.equal("漢  x")
}

pub fn wrap_expands_tabs_test() {
  text.wrap("a\tb", 20)
  |> should.equal(["a       b"])
}

// ─────────────────────────────────────────────────────────────────
// text: hard break of an unbreakable token

pub fn hard_break_keeps_chunk_order_test() {
  // A CJK paragraph has no spaces, so it is one token and goes through the
  // hard-break path. Chunks must come out in source order.
  text.wrap("漢字漢字漢字", 4)
  |> should.equal(["漢字", "漢字", "漢字"])
}

// ─────────────────────────────────────────────────────────────────
// geometry: rect helpers

pub fn inner_shrinks_on_all_sides_test() {
  geometry.inner(geometry.rect_new(2, 3, 10, 6), Margin(1, 2))
  |> should.equal(Rect(Position(3, 5), Size(8, 2)))
}

pub fn inner_collapses_instead_of_going_negative_test() {
  geometry.inner(geometry.rect_new(0, 0, 2, 2), Margin(5, 5)).size
  |> should.equal(Size(0, 0))
}

pub fn offset_moves_without_resizing_test() {
  geometry.offset(geometry.rect_new(1, 1, 4, 4), 2, -1)
  |> should.equal(Rect(Position(3, 0), Size(4, 4)))
}

pub fn clamp_pulls_rect_inside_bounds_test() {
  let bounds = geometry.rect_new(0, 0, 10, 10)
  geometry.clamp(geometry.rect_new(8, 8, 5, 5), bounds)
  |> should.equal(Rect(Position(5, 5), Size(5, 5)))
}

pub fn clamp_shrinks_a_rect_larger_than_bounds_test() {
  let bounds = geometry.rect_new(0, 0, 4, 4)
  geometry.clamp(geometry.rect_new(0, 0, 20, 20), bounds)
  |> should.equal(Rect(Position(0, 0), Size(4, 4)))
}

pub fn rows_yields_one_rect_per_row_test() {
  geometry.rows(geometry.rect_new(1, 1, 3, 2))
  |> should.equal([
    Rect(Position(1, 1), Size(3, 1)),
    Rect(Position(1, 2), Size(3, 1)),
  ])
}

pub fn columns_yields_one_rect_per_column_test() {
  geometry.columns(geometry.rect_new(0, 0, 2, 3))
  |> should.equal([
    Rect(Position(0, 0), Size(1, 3)),
    Rect(Position(1, 0), Size(1, 3)),
  ])
}

pub fn rows_of_an_empty_rect_is_empty_test() {
  geometry.rows(geometry.rect_zero())
  |> should.equal([])
}

// ─────────────────────────────────────────────────────────────────
// buffer: blit

fn text_at(buf: buffer.Buffer, y: Int, width: Int) -> String {
  row_text(buf, 0, y, width, "")
}

fn row_text(
  buf: buffer.Buffer,
  x: Int,
  y: Int,
  width: Int,
  acc: String,
) -> String {
  case x >= width {
    True -> acc
    False ->
      row_text(
        buf,
        x + 1,
        y,
        width,
        acc <> buffer.cell_symbol(buffer.get_cell(buf, Position(x, y))),
      )
  }
}

fn filled(area: Rect, row: String) -> buffer.Buffer {
  buffer.buffer_new_filled(
    area,
    row,
    style.Default,
    style.Default,
    style.none(),
  )
}

pub fn blit_copies_a_window_and_translates_it_test() {
  let src = filled(geometry.rect_new(0, 0, 6, 2), "abcdef")
  let dst = buffer.buffer_new(geometry.rect_new(0, 0, 6, 2))
  // Take columns 2..4 of the source, land them at x = 0.
  let out = buffer.blit(dst, src, geometry.rect_new(2, 0, 3, 1), Position(0, 0))
  text_at(out, 0, 6)
  |> should.equal("cde   ")
}

pub fn blit_clips_against_the_destination_test() {
  let src = filled(geometry.rect_new(0, 0, 4, 1), "wxyz")
  let dst = buffer.buffer_new(geometry.rect_new(0, 0, 4, 1))
  // Landing at x = 2 pushes the last two cells off the right edge.
  let out = buffer.blit(dst, src, geometry.rect_new(0, 0, 4, 1), Position(2, 0))
  text_at(out, 0, 4)
  |> should.equal("  wx")
}

pub fn blit_of_a_disjoint_window_is_a_no_op_test() {
  let src = filled(geometry.rect_new(0, 0, 2, 1), "ab")
  let dst = filled(geometry.rect_new(0, 0, 2, 1), "..")
  let out =
    buffer.blit(dst, src, geometry.rect_new(50, 50, 2, 1), Position(0, 0))
  text_at(out, 0, 2)
  |> should.equal("..")
}

// ─────────────────────────────────────────────────────────────────
// buffer: wide graphemes at a clip boundary
//
// These run on both targets on purpose: the Erlang fill path is native and
// the JavaScript one falls back to the Gleam body, and the two used to
// disagree about non-ASCII input.

fn wide_row() -> buffer.Buffer {
  // [漢, cont, 字, cont, a, b]
  buffer.buffer_new(geometry.rect_new(0, 0, 6, 1))
  |> buffer.set_string(
    Position(0, 0),
    "漢字ab",
    style.Default,
    style.Default,
    style.none(),
  )
}

fn shape(buf: buffer.Buffer, x: Int) -> String {
  let cell = buffer.get_cell(buf, Position(x, 0))
  case buffer.is_continuation(cell) {
    True -> "<cont>"
    False -> buffer.cell_symbol(cell)
  }
}

pub fn set_string_lays_wide_graphemes_over_two_cells_test() {
  let buf = wide_row()
  #(shape(buf, 0), shape(buf, 1), shape(buf, 2), shape(buf, 3), shape(buf, 4))
  |> should.equal(#("漢", "<cont>", "字", "<cont>", "a"))
}

pub fn buffer_new_filled_keeps_non_ascii_test() {
  // The Erlang fill_all_rows path used to drop every non-ASCII byte without
  // emitting a cell, so this row came back as "b" on Erlang and "漢<cont>b"
  // on JavaScript.
  let buf = filled(geometry.rect_new(0, 0, 4, 1), "漢b")
  #(shape(buf, 0), shape(buf, 1), shape(buf, 2))
  |> should.equal(#("漢", "<cont>", "b"))
}

pub fn a_wide_grapheme_that_cannot_fit_leaves_the_cell_blank_test() {
  // Only one column left: drawing 漢 there would overflow the clip boundary.
  let buf =
    buffer.buffer_new(geometry.rect_new(0, 0, 2, 1))
    |> buffer.set_string(
      Position(1, 0),
      "漢",
      style.Default,
      style.Default,
      style.none(),
    )
  shape(buf, 1)
  |> should.equal(" ")
}

pub fn blit_blanks_a_leading_orphan_continuation_test() {
  // Window starts on the right half of 漢. Copying the bare continuation
  // would render as nothing and shift the whole row one cell left.
  let dst = buffer.buffer_new(geometry.rect_new(0, 0, 6, 1))
  let out =
    buffer.blit(dst, wide_row(), geometry.rect_new(1, 0, 4, 1), Position(0, 0))
  #(shape(out, 0), shape(out, 1), shape(out, 2), shape(out, 3))
  |> should.equal(#(" ", "字", "<cont>", "a"))
}

pub fn blit_blanks_a_trailing_half_grapheme_test() {
  // Window ends on the left half of 字; its continuation is outside.
  let dst = buffer.buffer_new(geometry.rect_new(0, 0, 6, 1))
  let out =
    buffer.blit(dst, wide_row(), geometry.rect_new(0, 0, 3, 1), Position(0, 0))
  #(shape(out, 0), shape(out, 1), shape(out, 2))
  |> should.equal(#("漢", "<cont>", " "))
}

pub fn blit_of_a_clean_window_keeps_the_pair_intact_test() {
  let dst = buffer.buffer_new(geometry.rect_new(0, 0, 6, 1))
  let out =
    buffer.blit(dst, wide_row(), geometry.rect_new(0, 0, 4, 1), Position(0, 0))
  #(shape(out, 0), shape(out, 1), shape(out, 2), shape(out, 3))
  |> should.equal(#("漢", "<cont>", "字", "<cont>"))
}

pub fn to_ansi_of_a_blitted_window_fills_every_column_test() {
  // The regression this whole group exists for: an orphan continuation emits
  // no text, so the rendered row came out one cell short and everything after
  // it drew in the wrong column.
  let dst = buffer.buffer_new(geometry.rect_new(0, 0, 4, 1))
  let out =
    buffer.blit(dst, wide_row(), geometry.rect_new(1, 0, 4, 1), Position(0, 0))
  buffer.to_ansi(out)
  |> string.replace("\u{001B}[1;1H", "")
  |> text.cell_width
  |> should.equal(4)
}

// ─────────────────────────────────────────────────────────────────
// buffer: set_style

pub fn set_style_repaints_without_touching_content_test() {
  let area = geometry.rect_new(0, 0, 4, 1)
  let buf = filled(area, "abcd")
  let red = style.default_style() |> style.with_fg(style.Indexed(1))
  let out = buffer.set_style(buf, geometry.rect_new(1, 0, 2, 1), red)

  text_at(out, 0, 4)
  |> should.equal("abcd")
  buffer.cell_fg(buffer.get_cell(out, Position(1, 0)))
  |> should.equal(style.Indexed(1))
  buffer.cell_fg(buffer.get_cell(out, Position(0, 0)))
  |> should.equal(style.Default)
}

pub fn set_style_clips_to_the_buffer_test() {
  let area = geometry.rect_new(0, 0, 2, 1)
  let buf = filled(area, "ab")
  let red = style.default_style() |> style.with_fg(style.Indexed(1))
  // Rect extends past the buffer; the in-bounds part must still be styled.
  let out = buffer.set_style(buf, geometry.rect_new(1, 0, 10, 1), red)
  buffer.cell_fg(buffer.get_cell(out, Position(1, 0)))
  |> should.equal(style.Indexed(1))
}

// ─────────────────────────────────────────────────────────────────
// buffer: clear (rewritten to clip once instead of per cell)

pub fn clear_resets_only_the_given_rect_test() {
  let area = geometry.rect_new(0, 0, 4, 1)
  let out = buffer.clear(filled(area, "abcd"), geometry.rect_new(1, 0, 2, 1))
  text_at(out, 0, 4)
  |> should.equal("a  d")
}

pub fn clear_outside_the_buffer_is_a_no_op_test() {
  let area = geometry.rect_new(0, 0, 3, 1)
  let out = buffer.clear(filled(area, "xyz"), geometry.rect_new(9, 9, 2, 2))
  text_at(out, 0, 3)
  |> should.equal("xyz")
}
