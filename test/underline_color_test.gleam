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

// ─────────────────────────────────────────────────────────────────
// The two fill implementations
//
// Erlang fills through a native module and JavaScript through the Gleam
// fallback, so every property below has to be asserted rather than inferred
// from the other target. Wide graphemes go through the branch that writes two
// cells, which is where a style is easiest to drop.

pub fn wide_grapheme_continuation_carries_the_style_test() {
  let s =
    style.new(style.Indexed(4), style.Default, style.underline())
    |> style.with_underline_color(style.Indexed(9))
  let buf =
    buffer.buffer_new(rect(4, 1))
    |> buffer.set_string(Position(0, 0), "漢", s)

  let lead = buffer.get_cell(buf, Position(0, 0))
  let trail = buffer.get_cell(buf, Position(1, 0))

  buffer.is_continuation(trail) |> should.equal(True)
  // The trailing half is never drawn on its own, but it is compared: a
  // continuation that kept a different style would repaint every frame.
  buffer.cell_style(trail) |> should.equal(buffer.cell_style(lead))
  buffer.cell_underline_color(trail) |> should.equal(style.Indexed(9))
}

pub fn filled_buffer_carries_the_underline_color_test() {
  let s =
    style.new(style.Default, style.Default, style.underline())
    |> style.with_underline_color(style.Rgb(1, 2, 3))
  let buf = buffer.buffer_new_filled(rect(3, 2), "ab", s)

  buffer.get_cell(buf, Position(0, 1))
  |> buffer.cell_underline_color
  |> should.equal(style.Rgb(1, 2, 3))
}

/// The bulk path pads short rows with blank cells. A blank must not inherit
/// the underline colour of the text beside it, or the squiggle runs to the
/// end of the row.
pub fn filled_buffer_padding_stays_default_test() {
  let s =
    style.new(style.Default, style.Default, style.underline())
    |> style.with_underline_color(style.Rgb(1, 2, 3))
  let buf = buffer.buffer_new_filled(rect(4, 1), "ab", s)

  buffer.get_cell(buf, Position(3, 0))
  |> buffer.cell_underline_color
  |> should.equal(style.Default)
}

pub fn blit_carries_the_underline_color_test() {
  let s =
    style.new(style.Default, style.Default, style.underline())
    |> style.with_underline_color(style.Indexed(5))
  let src =
    buffer.buffer_new(rect(2, 1))
    |> buffer.set_string(Position(0, 0), "ab", s)
  let dst =
    buffer.buffer_new(rect(4, 1))
    |> buffer.blit(src, rect(2, 1), Position(2, 0))

  buffer.get_cell(dst, Position(2, 0))
  |> buffer.cell_underline_color
  |> should.equal(style.Indexed(5))
}

// ─────────────────────────────────────────────────────────────────
// Resolution at every door
//
// A cell holds a settled style wherever it entered from, not only through
// `set_string`.

pub fn set_cell_resolves_test() {
  let s =
    style.new(style.Default, style.Default, style.bold())
    |> style.remove_modifier(style.bold())
  let cell = buffer.Cell(content: buffer.Content("x", 1), style: s, link: "")

  let stored =
    buffer.buffer_new(rect(1, 1))
    |> buffer.set_cell(Position(0, 0), cell)
    |> buffer.get_cell(Position(0, 0))
    |> buffer.cell_style

  style.has(stored.modifier, style.bold()) |> should.equal(False)
  style.is_none(stored.sub_modifier) |> should.equal(True)
}

pub fn continuation_cell_resolves_test() {
  let s =
    style.new(style.Default, style.Default, style.bold())
    |> style.remove_modifier(style.bold())
  let stored = buffer.cell_style(buffer.continuation_cell(s))

  style.has(stored.modifier, style.bold()) |> should.equal(False)
  style.is_none(stored.sub_modifier) |> should.equal(True)
}

/// A hand-built cell and a written one must be interchangeable, or a widget
/// that composes cells directly would repaint rows that did not change.
pub fn a_hand_built_cell_equals_a_written_one_test() {
  let s = style.new(style.Indexed(2), style.Default, style.underline())
  let written =
    buffer.buffer_new(rect(1, 1))
    |> buffer.set_string(Position(0, 0), "x", s)
  let built =
    buffer.buffer_new(rect(1, 1))
    |> buffer.set_cell(
      Position(0, 0),
      buffer.Cell(content: buffer.Content("x", 1), style: s, link: ""),
    )

  buffer.diff(written, built) |> should.equal([])
}

// ─────────────────────────────────────────────────────────────────
// What the terminal receives

/// Dropping the colour must clear it. Without the reset the next word keeps
/// the squiggle of the misspelled one before it.
pub fn leaving_a_colored_underline_resets_test() {
  let coloured =
    style.new(style.Default, style.Default, style.underline())
    |> style.with_underline_color(style.Indexed(9))
  let out =
    buffer.buffer_new(rect(4, 1))
    |> buffer.set_string(Position(0, 0), "ab", coloured)
    |> buffer.set_string(Position(2, 0), "cd", style.default_style())
    |> buffer.to_ansi

  string.contains(out, "\u{001B}[58;5;9m") |> should.equal(True)
  string.contains(out, style.ansi_reset()) |> should.equal(True)
}

pub fn adjacent_colors_both_appear_test() {
  let base = style.new(style.Default, style.Default, style.underline())
  let out =
    buffer.buffer_new(rect(4, 1))
    |> buffer.set_string(
      Position(0, 0),
      "ab",
      style.with_underline_color(base, style.Indexed(1)),
    )
    |> buffer.set_string(
      Position(2, 0),
      "cd",
      style.with_underline_color(base, style.Indexed(2)),
    )
    |> buffer.to_ansi

  string.contains(out, "\u{001B}[58;5;1m") |> should.equal(True)
  string.contains(out, "\u{001B}[58;5;2m") |> should.equal(True)
}

/// A hyperlink and a coloured underline on the same cell: both sequences, and
/// the link is opened after the style so the reset cannot swallow it.
pub fn link_and_underline_color_coexist_test() {
  let s =
    style.new(style.Default, style.Default, style.underline())
    |> style.with_underline_color(style.Indexed(4))
  let out =
    buffer.buffer_new(rect(4, 1))
    |> buffer.set_string_linked(Position(0, 0), "docs", s, "https://gleam.run")
    |> buffer.to_ansi

  string.contains(out, "\u{001B}[58;5;4m") |> should.equal(True)
  string.contains(out, "https://gleam.run") |> should.equal(True)
}

// ─────────────────────────────────────────────────────────────────
// Wrapping

/// Wrapping cuts spans. Each piece keeps the colour of the span it came from,
/// which is the whole reason a squiggle survives a reflow.
pub fn wrapping_keeps_the_underline_color_test() {
  let squiggle =
    span.span_styled("supercalifragilistic", style.underline_style())
    |> span.span_underline_color(style.Rgb(220, 60, 60))
  let wrapped = span.wrap(span.text_new([span.line_new([squiggle])]), 8)

  let colours =
    list.flat_map(wrapped.lines, fn(l) {
      list.map(l.spans, fn(sp) { sp.style.underline_color })
    })

  list.all(colours, fn(c) { c == style.Rgb(220, 60, 60) })
  |> should.equal(True)
  { list.length(colours) > 1 } |> should.equal(True)
}

/// Nothing shared: two styles built separately, two buffers filled
/// separately. The identity shortcut in the diff cannot answer this one, so
/// this is the test that fails if the structural fallback behind it breaks.
pub fn separately_built_equal_cells_still_compare_equal_test() {
  let a =
    buffer.buffer_new(rect(3, 1))
    |> buffer.set_string(
      Position(0, 0),
      "abc",
      style.new(style.Indexed(2), style.Indexed(0), style.underline())
        |> style.with_underline_color(style.Rgb(9, 9, 9)),
    )
  let b =
    buffer.buffer_new(rect(3, 1))
    |> buffer.set_string(
      Position(0, 0),
      "abc",
      style.new(style.Indexed(2), style.Indexed(0), style.underline())
        |> style.with_underline_color(style.Rgb(9, 9, 9)),
    )

  buffer.diff(a, b) |> should.equal([])
}

/// And the mirror: one field apart, still a repaint. An identity check that
/// answered "equal" too eagerly would show up here.
pub fn one_field_apart_is_not_equal_test() {
  let base = style.new(style.Indexed(2), style.Indexed(0), style.underline())
  let a =
    buffer.buffer_new(rect(3, 1))
    |> buffer.set_string(Position(0, 0), "abc", base)
  let b =
    buffer.buffer_new(rect(3, 1))
    |> buffer.set_string(
      Position(0, 0),
      "abc",
      style.with_underline_color(base, style.Rgb(9, 9, 9)),
    )

  buffer.diff(a, b) |> list.length |> should.equal(1)
}
