/// Wrapping that keeps the styles.
///
/// Wrapping used to work only on a flat `String`, so text that needed both
/// mixed styles and reflowing could not have both. These check that the styles
/// travel with the words rather than with the columns they started in.
import etui/buffer
import etui/geometry
import etui/span.{type Line, type Text, Line, Span}
import etui/style
import etui/text
import etui/widgets/paragraph
import gleam/list
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
      #(sp.content, style.has(sp.modifier, style.bold()))
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
    list.all(l.spans, fn(sp) { style.has(sp.modifier, style.bold()) })
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
