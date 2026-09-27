/// Wrapping that keeps the styles.
///
/// Wrapping used to work only on a flat `String`, so text that needed both
/// mixed styles and reflowing could not have both. These check that the styles
/// travel with the words rather than with the columns they started in.
import etui/buffer
import etui/geometry.{Position, Rect, Size}
import etui/span.{type Line, type Span, type Text, Line, Span}
import etui/style
import etui/text
import etui/widgets/paragraph
import gleam/int
import gleam/list
import gleam/result
import gleam/string
import gleeunit/should

fn rendered(t: Text) -> List(String) {
  list.map(t.lines, fn(l) {
    list.fold(l.spans, "", fn(acc, sp) { acc <> sp.content })
  })
}

fn styles_of(t: Text) -> List(List(#(String, Bool))) {
  list.map(t.lines, fn(l) {
    list.map(l.spans, fn(sp) {
      #(sp.content, style.has(sp.style.modifier, style.bold()))
    })
  })
}

fn one(l: Line) -> Text {
  span.text_new([l])
}

// ─────────────────────────────────────────────────────────────────
// The thing this exists for

pub fn a_style_survives_the_line_break_test() {
  // "ERROR" is bold and sits at the start; " disk full here" is not. Wrapping
  // has to cut inside the plain span without the bold leaking across.
  let line =
    span.line_new([
      span.span_bold("ERROR"),
      span.span_plain(" disk full here"),
    ])
  let wrapped = span.wrap(one(line), 12)
  rendered(wrapped)
  |> should.equal(["ERROR disk", "full here"])
  styles_of(wrapped)
  |> should.equal([
    [#("ERROR", True), #(" disk", False)],
    [#("full here", False)],
  ])
}

pub fn a_style_that_starts_mid_line_moves_with_its_word_test() {
  let line =
    span.line_new([
      span.span_plain("the "),
      span.span_bold("important"),
      span.span_plain(" part"),
    ])
  let wrapped = span.wrap(one(line), 10)
  rendered(wrapped)
  |> should.equal(["the", "important", "part"])
  styles_of(wrapped)
  |> should.equal([
    [#("the", False)],
    [#("important", True)],
    [#("part", False)],
  ])
}

pub fn adjacent_words_of_one_style_stay_one_span_test() {
  // A wrapped line should not come back as one span per word.
  let line = span.line_new([span.span_plain("a b c d")])
  case span.wrap(one(line), 20).lines {
    [Line(spans: [Span(content: content, ..)], ..)] ->
      content
      |> should.equal("a b c d")
    other -> {
      list.length(other)
      |> should.equal(1)
      Nil
    }
  }
}

// ─────────────────────────────────────────────────────────────────
// Agreeing with the plain-string wrapper

pub fn plain_text_wraps_like_text_wrap_test() {
  let body = "the quick brown fox jumps over the lazy dog"
  rendered(span.wrap(span.text_plain(body), 15))
  |> should.equal(text.wrap(body, 15))
}

pub fn newlines_start_new_lines_test() {
  rendered(span.wrap(span.text_plain("one\ntwo"), 20))
  |> should.equal(["one", "two"])
}

pub fn carriage_returns_are_normalised_test() {
  rendered(span.wrap(span.text_plain("one\r\ntwo"), 20))
  |> should.equal(["one", "two"])
}

// ─────────────────────────────────────────────────────────────────
// Words that do not fit

pub fn a_word_wider_than_the_line_is_broken_test() {
  let line = span.line_new([span.span_bold("supercalifragilistic")])
  let wrapped = span.wrap(one(line), 8)
  rendered(wrapped)
  |> should.equal(["supercal", "ifragili", "stic"])
  // Every piece keeps the style it was cut from.
  list.all(wrapped.lines, fn(l) {
    list.all(l.spans, fn(sp) { style.has(sp.style.modifier, style.bold()) })
  })
  |> should.equal(True)
}

pub fn a_long_word_after_a_short_one_starts_where_it_fits_test() {
  rendered(span.wrap(
    one(span.line_new([span.span_plain("hi enormouslylong")])),
    8,
  ))
  |> should.equal(["hi enorm", "ouslylon", "g"])
}

// ─────────────────────────────────────────────────────────────────
// Wide graphemes

pub fn wide_graphemes_count_two_cells_test() {
  // Four CJK characters are eight cells, so a width of 8 holds exactly one
  // word and no more.
  let line = span.line_new([span.span_plain("漢字漢字 漢字漢字")])
  rendered(span.wrap(one(line), 8))
  |> should.equal(["漢字漢字", "漢字漢字"])
}

pub fn a_wide_word_breaks_on_a_grapheme_boundary_test() {
  // Never mid-character: a width of 5 fits two wide graphemes, not two and a
  // half.
  rendered(span.wrap(one(span.line_new([span.span_plain("漢字漢字")])), 5))
  |> should.equal(["漢字", "漢字"])
}

// ─────────────────────────────────────────────────────────────────
// Edges

pub fn an_empty_line_stays_one_empty_line_test() {
  // Dropping it would silently close up a paragraph break.
  span.wrap(one(span.line_new([])), 10).lines
  |> list.length
  |> should.equal(1)
}

pub fn a_zero_width_yields_nothing_test() {
  span.wrap(span.text_plain("anything"), 0).lines
  |> should.equal([])
}

pub fn alignment_is_carried_to_every_wrapped_row_test() {
  let line =
    span.line_aligned([span.span_plain("one two three four")], text.Center)
  span.wrap(one(line), 8).lines
  |> list.all(fn(l) { l.alignment == text.Center })
  |> should.equal(True)
}

pub fn height_counts_the_rows_after_wrapping_test() {
  span.wrap(span.text_plain("one two three four five"), 9)
  |> span.text_height
  |> should.equal(3)
}

// ─────────────────────────────────────────────────────────────────
// Reaching the screen

pub fn render_text_wraps_to_the_area_width_test() {
  // The capability is only worth anything if it draws. Two rows of a narrow
  // area, from one line that did not fit.
  let area = geometry.rect_new(0, 0, 12, 3)
  let content =
    span.text_new([
      span.line_new([span.span_bold("ERROR"), span.span_plain(" disk full")]),
    ])
  let buf = paragraph.render_text(buffer.buffer_new(area), area, content)
  [row(buf, 0, 12), row(buf, 1, 12)]
  |> should.equal(["ERROR disk  ", "full        "])
}

pub fn render_text_keeps_the_style_on_the_first_row_test() {
  let area = geometry.rect_new(0, 0, 12, 3)
  let content =
    span.text_new([
      span.line_new([span.span_bold("ERROR"), span.span_plain(" disk full")]),
    ])
  let buf = paragraph.render_text(buffer.buffer_new(area), area, content)
  style.has(
    buffer.cell_modifier(buffer.get_cell(buf, geometry.Position(0, 0))),
    style.bold(),
  )
  |> should.equal(True)
  style.has(
    buffer.cell_modifier(buffer.get_cell(buf, geometry.Position(6, 0))),
    style.bold(),
  )
  |> should.equal(False)
}

fn row(buf: buffer.Buffer, y: Int, w: Int) -> String {
  read_row(buf, y, 0, w, "")
}

fn read_row(buf: buffer.Buffer, y: Int, x: Int, w: Int, acc: String) -> String {
  case x >= w {
    True -> acc
    False ->
      read_row(
        buf,
        y,
        x + 1,
        w,
        acc <> buffer.cell_symbol(buffer.get_cell(buf, geometry.Position(x, y))),
      )
  }
}

// ─────────────────────────────────────────────────────────────────
// Words that span a style boundary

pub fn punctuation_in_another_style_stays_attached_test() {
  // "etui.log" and "," are adjacent with no space between them, so they are
  // one word. Splitting each span on spaces and rejoining with spaces put a
  // space between them that the source never had.
  let line =
    span.line_new([
      span.span_plain("rotating "),
      span.span_bold("etui.log"),
      span.span_plain(", nothing since"),
    ])
  rendered(span.wrap(one(line), 40))
  |> should.equal(["rotating etui.log, nothing since"])
}

pub fn a_word_split_across_styles_is_never_broken_by_the_wrap_test() {
  // The word is 12 cells and the column is 14, so it fits only if it is kept
  // whole. If the wrapper treated the two halves as separate words it would
  // insert a space and push one of them to the next row.
  let line =
    span.line_new([
      span.span_plain("x "),
      span.span_bold("half"),
      span.span_plain("andhalf"),
    ])
  rendered(span.wrap(one(line), 14))
  |> should.equal(["x halfandhalf"])
}

pub fn each_half_of_such_a_word_keeps_its_own_style_test() {
  let line = span.line_new([span.span_bold("half"), span.span_plain("andhalf")])
  styles_of(span.wrap(one(line), 20))
  |> should.equal([[#("half", True), #("andhalf", False)]])
}

pub fn a_trailing_space_still_ends_a_word_test() {
  let line = span.line_new([span.span_bold("one "), span.span_plain("two")])
  rendered(span.wrap(one(line), 3))
  |> should.equal(["one", "two"])
}

/// The space between two words belongs to neither of them.
///
/// The wrapper drops the separating space at a line break and re-emits it
/// between words that share a row. It used to re-emit it with the style of
/// the word that followed, which nothing noticed while styles were colours on
/// glyphs: a space has no glyph to colour. An underline does paint a space,
/// so the line under a marked word started one cell early.
pub fn the_separator_space_does_not_take_the_next_words_style_test() {
  let marked =
    span.span_styled("teh", style.underline_style())
    |> span.span_underline_color(style.Rgb(255, 0, 0))
  let line = span.line_new([span.span_plain("a "), marked])
  let buf =
    span.render_line(
      buffer.buffer_new(Rect(Position(0, 0), Size(width: 6, height: 1))),
      Position(0, 0),
      span.wrap_line(line, 6) |> list.first |> result.unwrap(line),
      6,
    )

  // Cell 1 is the space between "a" and "teh".
  let gap = buffer.get_cell(buf, Position(1, 0))
  style.has(buffer.cell_modifier(gap), style.underline()) |> should.equal(False)
  buffer.cell_underline_color(gap) |> should.equal(style.Default)

  // And the word itself still has both.
  let word = buffer.get_cell(buf, Position(2, 0))
  style.has(buffer.cell_modifier(word), style.underline())
  |> should.equal(True)
  buffer.cell_underline_color(word) |> should.equal(style.Rgb(255, 0, 0))
}

/// The mirror: a space that was inside a styled span keeps that style, so a
/// highlighted phrase does not come back with holes where its spaces were.
pub fn a_space_inside_a_styled_span_keeps_its_style_test() {
  let highlight = style.new(style.Indexed(0), style.Indexed(4), style.none())
  let line = span.line_new([span.span_styled("two words", highlight)])
  let buf =
    span.render_line(
      buffer.buffer_new(Rect(Position(0, 0), Size(width: 9, height: 1))),
      Position(0, 0),
      span.wrap_line(line, 9) |> list.first |> result.unwrap(line),
      9,
    )

  buffer.cell_bg(buffer.get_cell(buf, Position(3, 0)))
  |> should.equal(style.Indexed(4))
}

// ─────────────────────────────────────────────────────────────────
// Graphemes wider than the row
//
// A 2-cell grapheme at a width of 1 fits nowhere. The wrapper used to requeue
// it forever, which hung the caller; a row now always takes at least one
// grapheme, and the only row allowed past the width is one holding a single
// grapheme wider than the row.

pub fn a_wide_grapheme_at_width_one_gets_a_row_of_its_own_test() {
  rendered(span.wrap(one(span.line_new([span.span_plain("中")])), 1))
  |> should.equal(["中"])
}

pub fn wide_graphemes_inside_a_word_each_take_a_row_test() {
  // The narrow graphemes either side still get rows of their own, and no
  // empty row is left behind where the wide one could not fit.
  rendered(span.wrap(one(span.line_new([span.span_plain("a中b漢")])), 1))
  |> should.equal(["a", "中", "b", "漢"])
}

pub fn a_wide_word_after_a_narrow_one_at_width_one_test() {
  rendered(span.wrap(one(span.line_new([span.span_plain("x 中文 y")])), 1))
  |> should.equal(["x", "中", "文", "y"])
}

pub fn an_over_wide_grapheme_keeps_its_style_test() {
  let line = span.line_new([span.span_bold("中"), span.span_plain(" a")])
  styles_of(span.wrap(one(line), 1))
  |> should.equal([[#("中", True)], [#("a", False)]])
}

pub fn a_wide_grapheme_at_width_zero_yields_nothing_test() {
  span.wrap(one(span.line_new([span.span_plain("中")])), 0).lines
  |> should.equal([])
}

pub fn a_zero_width_joiner_sequence_is_never_split_test() {
  // A family emoji is one grapheme of several codepoints joined by ZWJ. At a
  // width of 1 it overflows whole rather than being cut between codepoints,
  // and at 3 two of them still cannot share a row.
  let family = "👨\u{200D}👩\u{200D}👧"
  rendered(span.wrap(one(span.line_new([span.span_plain(family)])), 1))
  |> should.equal([family])

  rendered(span.wrap(one(span.line_new([span.span_plain(family <> family)])), 3))
  |> should.equal([family, family])
}

pub fn a_regional_indicator_flag_is_never_split_test() {
  // A flag is two regional indicators forming one grapheme. Splitting it
  // would leave two stray letters, so each flag takes a row at width 1.
  let jp = "\u{1F1EF}\u{1F1F5}"
  let us = "\u{1F1FA}\u{1F1F8}"
  rendered(span.wrap(one(span.line_new([span.span_plain(jp <> us)])), 1))
  |> should.equal([jp, us])
}

pub fn text_wrap_also_gives_a_wide_grapheme_a_row_test() {
  // The flat wrapper already followed the same rule; this pins it.
  text.wrap("a中b", 1)
  |> should.equal(["a", "中", "b"])
}

// ─── Property: the wrapper terminates and loses nothing ────────────
//
// Random lines of mixed styles drawn from narrow, wide, joined and flag
// graphemes, wrapped at every width from 1 to 6. Reaching the assertion at all
// is the termination half. The rest checks that the rows carry exactly the
// source's non-space text, in order, and that a row exceeds the width only
// when it is a single grapheme wider than the row.

const alphabet = [
  "a", "b", "中", "漢", "👨\u{200D}👩\u{200D}👧", "\u{1F1EF}\u{1F1F5}", "e\u{0301}",
  " ",
]

fn lcg(seed: Int) -> Int {
  let r = { seed * 1_664_525 + 1_013_904_223 } % 2_147_483_647
  case r < 0 {
    True -> r + 2_147_483_647
    False -> r
  }
}

fn pick(seed: Int) -> String {
  alphabet
  |> list.drop(seed % list.length(alphabet))
  |> list.first
  |> result.unwrap("a")
}

// A span of one to five graphemes, bold or plain by the seed.
fn gen_span(seed: Int) -> #(Span, Int) {
  let s1 = lcg(seed)
  let #(content, s2) =
    list.fold(list.repeat(Nil, s1 % 5 + 1), #("", s1), fn(acc, _) {
      let #(content, s) = acc
      let next = lcg(s)
      #(content <> pick(next), next)
    })

  let sp = case s2 % 2 {
    0 -> span.span_plain(content)
    _ -> span.span_bold(content)
  }
  #(sp, lcg(s2))
}

fn gen_line(seed: Int) -> #(Line, Int) {
  let s1 = lcg(seed)
  let #(spans, s2) =
    list.fold(list.repeat(Nil, s1 % 4 + 1), #([], s1), fn(acc, _) {
      let #(spans, s) = acc
      let #(sp, next) = gen_span(s)
      #([sp, ..spans], next)
    })
  #(span.line_new(list.reverse(spans)), s2)
}

fn line_text(l: Line) -> String {
  list.fold(l.spans, "", fn(acc, sp) { acc <> sp.content })
}

fn check_wrap(l: Line, width: Int) -> Result(Nil, String) {
  let source = line_text(l)
  let rows = span.wrap_line(l, width)
  let packed = string.concat(list.map(rows, line_text))
  let bounded =
    list.all(rows, fn(row) {
      span.line_width(row) <= width
      || list.length(string.to_graphemes(line_text(row))) == 1
    })

  let kept = string.replace(packed, " ", "") == string.replace(source, " ", "")
  case kept && bounded {
    True -> Ok(Nil)
    False ->
      Error(
        "width " <> int.to_string(width) <> " source " <> string.inspect(source),
      )
  }
}

fn run_wrap(seed: Int, rem: Int) -> Result(Nil, String) {
  case rem <= 0 {
    True -> Ok(Nil)
    False -> {
      let #(l, next) = gen_line(seed)
      use _ <- result.try(
        list.try_each([1, 2, 3, 4, 5, 6], fn(width) { check_wrap(l, width) }),
      )
      run_wrap(next, rem - 1)
    }
  }
}

pub fn prop_wrap_terminates_and_keeps_the_text_test() {
  run_wrap(2026, 300)
  |> should.equal(Ok(Nil))
}
