/// An underline that is not the colour of its text.
///
/// The modifier has existed since 1.0, but the underline always took the
/// foreground colour, so the one thing underlines are most used for — a red
/// squiggle under text that stays black — could not be said. SGR 58 says it,
/// and `Style` now carries the colour that fills it.
import etui/buffer
import etui/geometry.{type Rect, Position, Rect, Size}
import etui/span
import etui/style
import gleam/list
import gleam/string
import gleeunit/should

fn rect(w: Int, h: Int) -> Rect {
  Rect(position: Position(0, 0), size: Size(width: w, height: h))
}

// ─────────────────────────────────────────────────────────────────
// The sequence itself

pub fn ansi_underline_color_indexed_test() {
  style.ansi_underline_color(style.Indexed(9))
  |> should.equal("\u{001B}[58;5;9m")
}

/// The low 16 colours have no short form here, unlike fg (30-37) and bg
/// (40-47): SGR 58 only takes the 5 and 2 subforms. Indexed(1) is 58;5;1.
pub fn ansi_underline_color_low_index_has_no_short_form_test() {
  style.ansi_underline_color(style.Indexed(1))
  |> should.equal("\u{001B}[58;5;1m")
}

pub fn ansi_underline_color_rgb_test() {
  style.ansi_underline_color(style.Rgb(255, 85, 85))
  |> should.equal("\u{001B}[58;2;255;85;85m")
}

/// Default emits nothing rather than SGR 59: every cell is written after a
/// reset, so there is never a stale underline colour left to clear.
pub fn ansi_underline_color_default_is_empty_test() {
  style.ansi_underline_color(style.Default) |> should.equal("")
}

// ─────────────────────────────────────────────────────────────────
// Reaching a cell

pub fn cell_carries_underline_color_test() {
  let s =
    style.new(style.Default, style.Default, style.underline())
    |> style.with_underline_color(style.Rgb(255, 0, 0))
  let buf =
    buffer.buffer_new(rect(4, 1))
    |> buffer.set_string(Position(0, 0), "typo", s)

  buffer.get_cell(buf, Position(0, 0))
  |> buffer.cell_underline_color
  |> should.equal(style.Rgb(255, 0, 0))
}

pub fn rendered_frame_carries_the_sequence_test() {
  let s =
    style.new(style.Default, style.Default, style.underline())
    |> style.with_underline_color(style.Indexed(9))
  let out =
    buffer.buffer_new(rect(4, 1))
    |> buffer.set_string(Position(0, 0), "typo", s)
    |> buffer.to_ansi

  string.contains(out, "\u{001B}[58;5;9m") |> should.equal(True)
}

/// A run of identically styled cells pays for the sequence once. Emitting it
/// per cell would quadruple the bytes of an underlined line for no effect.
pub fn sequence_is_emitted_once_per_run_test() {
  let s =
    style.new(style.Default, style.Default, style.underline())
    |> style.with_underline_color(style.Indexed(9))
  let out =
    buffer.buffer_new(rect(4, 1))
    |> buffer.set_string(Position(0, 0), "typo", s)
    |> buffer.to_ansi

  string.split(out, "\u{001B}[58;5;9m")
  |> list.length
  |> should.equal(2)
}

/// The underline colour is part of a cell's identity: changing only it must
/// still repaint, or the squiggle keeps the colour of the word before it.
pub fn changing_only_the_underline_color_is_a_diff_test() {
  let base = style.new(style.Default, style.Default, style.underline())
  let red = style.with_underline_color(base, style.Rgb(255, 0, 0))
  let blue = style.with_underline_color(base, style.Rgb(0, 0, 255))

  let a =
    buffer.buffer_new(rect(4, 1))
    |> buffer.set_string(Position(0, 0), "typo", red)
  let b =
    buffer.buffer_new(rect(4, 1))
    |> buffer.set_string(Position(0, 0), "typo", blue)

  buffer.diff(a, b) |> list.length |> should.equal(1)
}

// ─────────────────────────────────────────────────────────────────
// Layering

pub fn patch_falls_through_default_underline_color_test() {
  let base =
    style.default_style() |> style.with_underline_color(style.Indexed(9))
  let over = style.default_style() |> style.with_fg(style.Indexed(4))

  style.patch(base, over).underline_color
  |> should.equal(style.Indexed(9))
}

pub fn patch_overrides_underline_color_test() {
  let base =
    style.default_style() |> style.with_underline_color(style.Indexed(9))
  let over =
    style.default_style() |> style.with_underline_color(style.Indexed(2))

  style.patch(base, over).underline_color
  |> should.equal(style.Indexed(2))
}

// ─────────────────────────────────────────────────────────────────
// Resolution
//
// A cell holds a settled style. `sub_modifier` is an instruction about a
// style laid over another, not a property of a drawn cell, so it is spent
// on the way in.

pub fn writing_spends_the_sub_modifier_test() {
  let s =
    style.new(
      style.Default,
      style.Default,
      style.add(style.bold(), style.underline()),
    )
    |> style.remove_modifier(style.bold())

  let m =
    buffer.buffer_new(rect(2, 1))
    |> buffer.set_string(Position(0, 0), "ab", s)
    |> buffer.get_cell(Position(0, 0))
    |> buffer.cell_modifier

  style.has(m, style.bold()) |> should.equal(False)
  style.has(m, style.underline()) |> should.equal(True)
}

/// Two styles that describe the same drawn cell must produce equal cells.
/// If the unspent `sub_modifier` rode along, these two buffers would differ
/// and the diff would repaint the row every frame.
pub fn equivalent_styles_produce_no_diff_test() {
  let long =
    style.new(
      style.Default,
      style.Default,
      style.add(style.bold(), style.underline()),
    )
    |> style.remove_modifier(style.bold())
  let short = style.new(style.Default, style.Default, style.underline())

  let a =
    buffer.buffer_new(rect(2, 1))
    |> buffer.set_string(Position(0, 0), "ab", long)
  let b =
    buffer.buffer_new(rect(2, 1))
    |> buffer.set_string(Position(0, 0), "ab", short)

  buffer.diff(a, b) |> should.equal([])
}

pub fn set_style_also_resolves_test() {
  let s =
    style.new(style.Default, style.Default, style.bold())
    |> style.remove_modifier(style.bold())

  let m =
    buffer.buffer_new(rect(2, 1))
    |> buffer.set_style(rect(2, 1), s)
    |> buffer.get_cell(Position(0, 0))
    |> buffer.cell_modifier

  style.has(m, style.bold()) |> should.equal(False)
}

// ─────────────────────────────────────────────────────────────────
// Through styled text
//
// A span is where a squiggle actually lives: one misspelled word inside a
// line that is otherwise plain.

pub fn span_carries_underline_color_to_the_buffer_test() {
  let line =
    span.line_new([
      span.span_plain("a "),
      span.span_styled("teh", style.underline_style())
        |> span.span_underline_color(style.Rgb(255, 0, 0)),
      span.span_plain(" cat"),
    ])
  let buf =
    span.render_line(buffer.buffer_new(rect(9, 1)), Position(0, 0), line, 9)

  buffer.get_cell(buf, Position(2, 0))
  |> buffer.cell_underline_color
  |> should.equal(style.Rgb(255, 0, 0))

  // The plain text around it keeps the terminal's own underline colour.
  buffer.get_cell(buf, Position(0, 0))
  |> buffer.cell_underline_color
  |> should.equal(style.Default)
}
