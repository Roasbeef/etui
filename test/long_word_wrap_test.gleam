/// Breaking a word wider than the row, in time linear in its length.
///
/// `span.wrap_line` used to break such a word one row at a time, and every row
/// measured and re-joined all of the word that was left. A 50,000-character
/// word at a width of 80 took about two seconds. These check that it is now
/// fast, and that the rows it produces are the rows the old code did, apart
/// from where a zero-width grapheme lands at the end of a full row.
import etui/span.{type Line, type Span, Line, Span}
import etui/text
import gleam/int
import gleam/list
import gleam/result
import gleam/string
import gleeunit/should

@external(erlang, "etui_wrap_timing_ffi", "monotonic_ms")
@external(javascript, "./etui_wrap_timing_ffi.mjs", "monotonic_ms")
fn monotonic_ms() -> Int

fn line_text(l: Line) -> String {
  string.concat(list.map(l.spans, fn(sp) { sp.content }))
}

// ─── Timing ───────────────────────────────────────────────────────
//
// The old code took about two seconds for each of these words; the new one
// takes a few milliseconds. The budget sits far from both, so a slow or loaded
// machine does not fail the test and the old behaviour cannot pass it.

const budget_ms = 200

const long = 50_000

// Wrap `l` at a width of 80, and check the rows hold exactly the source text
// with none wider than the row. Returns the elapsed milliseconds.
fn timed_wrap(l: Line) -> Int {
  let start = monotonic_ms()
  let rows = span.wrap_line(l, 80)
  let elapsed = monotonic_ms() - start

  string.concat(list.map(rows, line_text))
  |> should.equal(line_text(l))
  list.all(rows, fn(row) { span.line_width(row) <= 80 })
  |> should.be_true
  elapsed
}

pub fn a_long_plain_word_wraps_in_linear_time_test() {
  let elapsed = timed_wrap(span.line_plain(string.repeat("[", long)))
  { elapsed < budget_ms }
  |> should.be_true
}

pub fn a_long_word_of_wide_graphemes_wraps_in_linear_time_test() {
  // Two wide and two narrow graphemes in each repeat, so rows end at an odd
  // column and the wide grapheme that would cross 80 moves to the next row.
  let elapsed = timed_wrap(span.line_plain(string.repeat("中a文b", long / 4)))
  { elapsed < budget_ms }
  |> should.be_true
}

pub fn a_long_styled_word_of_many_pieces_wraps_in_linear_time_test() {
  // One word made of three spans with no space between them. The rows take
  // the first piece's style, as they always have for a broken word.
  let l =
    span.line_new([
      span.span_plain("lead "),
      span.span_bold(string.repeat("x", 20_000)),
      span.span_italic(string.repeat("y", 20_000)),
      span.span_plain(string.repeat("漢", 5000)),
    ])
  let elapsed = timed_wrap(l)
  { elapsed < budget_ms }
  |> should.be_true
}

// ─── Equivalence with the old algorithm ───────────────────────────
//
// Random lines of words up to about 300 graphemes, in several styles, drawn
// from narrow, wide, combining, joined and flag graphemes, wrapped at every
// width from 1 to 20. The rows, spans and styles must be exactly what the old
// code produced. The old code is kept below as `old_wrap_line`. A second run
// adds zero-width graphemes, a lone combining mark and a zero-width space,
// where the old placement was inconsistent and the comparison ignores them.

const alphabet = [
  "[", "a", "b", "中", "漢", "👨\u{200D}👩\u{200D}👧", "\u{1F1EF}\u{1F1F5}",
  "e\u{0301}", " ",
]

fn lcg(seed: Int) -> Int {
  let r = { seed * 1_664_525 + 1_013_904_223 } % 2_147_483_647
  case r < 0 {
    True -> r + 2_147_483_647
    False -> r
  }
}

fn pick(seed: Int, alphabet: List(String)) -> String {
  alphabet
  |> list.drop(seed % list.length(alphabet))
  |> list.first
  |> result.unwrap("a")
}

// Mostly word characters, with a space about one time in twenty, so that
// most words are long enough to be broken.
fn pick_weighted(seed: Int, alphabet: List(String)) -> String {
  case seed % 20 {
    0 -> " "
    _ -> pick(seed / 20, alphabet)
  }
}

// A span of up to 150 graphemes in one of four styles.
fn gen_span(seed: Int, alphabet: List(String)) -> #(Span, Int) {
  let s1 = lcg(seed)
  let #(parts, s2) =
    list.fold(list.repeat(Nil, s1 % 150 + 1), #([], s1), fn(acc, _) {
      let #(parts, s) = acc
      let next = lcg(s)
      #([pick_weighted(next, alphabet), ..parts], next)
    })

  let content = string.concat(parts)
  let sp = case s2 % 4 {
    0 -> span.span_plain(content)
    1 -> span.span_bold(content)
    2 -> span.span_italic(content)
    _ -> span.span_link(content, "https://example.com")
  }
  #(sp, lcg(s2))
}

fn gen_line(seed: Int, alphabet: List(String)) -> #(Line, Int) {
  let s1 = lcg(seed)
  let #(spans, s2) =
    list.fold(list.repeat(Nil, s1 % 3 + 1), #([], s1), fn(acc, _) {
      let #(spans, s) = acc
      let #(sp, next) = gen_span(s, alphabet)
      #([sp, ..spans], next)
    })
  #(span.line_new(list.reverse(spans)), s2)
}

fn check_same(l: Line, width: Int) -> Result(Nil, String) {
  compare(l, width, span.wrap_line(l, width), old_wrap_line(l, width))
}

// Zero-width graphemes are the one place the rows may differ. The old code
// sometimes put one at the start of the next row instead of the end of the
// full row, and sometimes gave a run of them a row of its own; see the test
// after this one. Removing every zero-width grapheme from both sides, and then
// every row left empty, must leave them the same.
fn check_same_but_zero_width(l: Line, width: Int) -> Result(Nil, String) {
  let strip = fn(rows: List(Line)) {
    list.filter_map(rows, fn(row) {
      let stripped =
        Line(
          ..row,
          spans: list.map(row.spans, fn(sp) {
            Span(
              ..sp,
              content: string.to_graphemes(sp.content)
                |> list.filter(fn(g) { text.grapheme_cell_width(g) > 0 })
                |> string.concat,
            )
          }),
        )
      case line_text(stripped) {
        "" -> Error(Nil)
        _ -> Ok(stripped)
      }
    })
  }
  compare(
    l,
    width,
    strip(span.wrap_line(l, width)),
    strip(old_wrap_line(l, width)),
  )
}

fn compare(
  l: Line,
  width: Int,
  got: List(Line),
  want: List(Line),
) -> Result(Nil, String) {
  case got == want {
    True -> Ok(Nil)
    False ->
      Error(
        "width "
        <> int.to_string(width)
        <> " source "
        <> string.inspect(line_text(l)),
      )
  }
}

fn run_same(
  seed: Int,
  rem: Int,
  alphabet: List(String),
  check: fn(Line, Int) -> Result(Nil, String),
) -> Result(Nil, String) {
  case rem <= 0 {
    True -> Ok(Nil)
    False -> {
      let #(l, next) = gen_line(seed, alphabet)
      use _ <- result.try(
        list.try_each(one_to(20), fn(width) { check(l, width) }),
      )
      run_same(next, rem - 1, alphabet, check)
    }
  }
}

pub fn prop_rows_match_the_old_algorithm_test() {
  run_same(1789, 150, alphabet, check_same)
  |> should.equal(Ok(Nil))
}

pub fn prop_rows_match_the_old_algorithm_but_for_zero_width_test() {
  run_same(
    4242,
    150,
    ["\u{0301}", "\u{200B}", ..alphabet],
    check_same_but_zero_width,
  )
  |> should.equal(Ok(Nil))
}

pub fn a_zero_width_grapheme_stays_with_the_one_before_it_test() {
  // When a row was opened by a grapheme that filled it, the old code moved a
  // zero-width space after it to the next row, and when that next row had no
  // room for the grapheme after the space, it gave the space a row of its own
  // that drew as a blank line. A zero-width grapheme now always stays on the
  // row it follows, since it takes no cells there.
  let full = span.line_plain("ab 中\u{200B}中")
  rows_of(span.wrap_line(full, 2))
  |> should.equal(["ab", "中\u{200B}", "中"])
  rows_of(old_wrap_line(full, 2))
  |> should.equal(["ab", "中", "\u{200B}中"])

  let blank = span.line_plain("x a\u{200B}漢")
  rows_of(span.wrap_line(blank, 1))
  |> should.equal(["x", "a\u{200B}", "漢"])
  rows_of(old_wrap_line(blank, 1))
  |> should.equal(["x", "a", "\u{200B}", "漢"])
}

pub fn a_word_that_fills_the_rest_of_a_row_matches_the_old_algorithm_test() {
  // The first row of a broken word fills what is left of the row it starts
  // on, behind a separator in its own style.
  let l =
    span.line_new([
      span.span_bold("ab "),
      span.span_plain("cdefghijklmnop"),
      span.span_italic("qr 中文字"),
    ])
  list.each(one_to(12), fn(width) {
    span.wrap_line(l, width) |> should.equal(old_wrap_line(l, width))
  })
  rows_of(span.wrap_line(l, 5))
  |> should.equal(["ab cd", "efghi", "jklmn", "opqr", "中文", "字"])
}

fn rows_of(rows: List(Line)) -> List(String) {
  list.map(rows, line_text)
}

// The widths 1 to `n`, in order.
fn one_to(n: Int) -> List(Int) {
  list.map(list.repeat(Nil, n), fn(_) { 0 })
  |> list.index_map(fn(_, i) { i + 1 })
}

// ─── The old algorithm, kept as the reference ─────────────────────
//
// This is `wrap_line` and its helpers as they stood before the fix, copied
// unchanged apart from names. Its word breaking re-measures and re-joins the
// rest of the word for every row, which is the quadratic cost the fix removes.

type OldPiece {
  OldPiece(content: String, style: Span)
}

type OldWord {
  OldWord(sep: Span, pieces: List(OldPiece))
}

fn old_wrap_line(l: Line, width: Int) -> List(Line) {
  case width <= 0 {
    True -> []
    False ->
      case old_tokenise(l.spans) {
        [] -> [Line(spans: [], alignment: l.alignment)]
        words -> old_pack(words, width, l.alignment, 0, [], [])
      }
  }
}

fn old_word_width(w: OldWord) -> Int {
  list.fold(w.pieces, 0, fn(acc, p) { acc + text.cell_width(p.content) })
}

fn old_word_text(w: OldWord) -> String {
  string.concat(list.map(w.pieces, fn(p) { p.content }))
}

fn old_tokenise(spans: List(Span)) -> List(OldWord) {
  let blank = span.span_plain("")
  let #(words, pending, pending_sep) = old_tokenise_loop(spans, [], blank, [])
  let all = case pending {
    [] -> words
    _ -> [OldWord(sep: pending_sep, pieces: list.reverse(pending)), ..words]
  }
  list.reverse(all)
}

fn old_tokenise_loop(
  spans: List(Span),
  pending: List(OldPiece),
  pending_sep: Span,
  done: List(OldWord),
) -> #(List(OldWord), List(OldPiece), Span) {
  case spans {
    [] -> #(done, pending, pending_sep)
    [sp, ..rest] -> {
      let #(next_pending, next_sep, next_done) =
        old_absorb(
          string.split(sp.content, " "),
          sp,
          pending,
          pending_sep,
          done,
          True,
        )
      old_tokenise_loop(rest, next_pending, next_sep, next_done)
    }
  }
}

fn old_absorb(
  parts: List(String),
  sp: Span,
  pending: List(OldPiece),
  pending_sep: Span,
  done: List(OldWord),
  first: Bool,
) -> #(List(OldPiece), Span, List(OldWord)) {
  case parts {
    [] -> #(pending, pending_sep, done)
    [part, ..rest] -> {
      let #(carry, carry_sep, closed) = case first {
        True -> #(pending, pending_sep, done)
        False ->
          case pending {
            [] -> #([], sp, done)
            _ -> #([], sp, [
              OldWord(sep: pending_sep, pieces: list.reverse(pending)),
              ..done
            ])
          }
      }
      let grown = case part {
        "" -> carry
        _ -> [OldPiece(content: part, style: sp), ..carry]
      }
      old_absorb(rest, sp, grown, carry_sep, closed, False)
    }
  }
}

fn old_pack(
  words: List(OldWord),
  width: Int,
  alignment: text.Alignment,
  current_width: Int,
  current: List(Span),
  done: List(Line),
) -> List(Line) {
  case words {
    [] ->
      list.reverse([
        Line(spans: list.reverse(current), alignment: alignment),
        ..done
      ])
    [w, ..rest] -> {
      let this_width = old_word_width(w)
      let gap = case current {
        [] -> 0
        _ -> 1
      }
      case current_width + gap + this_width <= width {
        True ->
          old_pack(
            rest,
            width,
            alignment,
            current_width + gap + this_width,
            old_push_word(current, w, gap),
            done,
          )
        False ->
          case this_width <= width {
            True ->
              old_pack(
                rest,
                width,
                alignment,
                this_width,
                old_push_word([], w, 0),
                old_flush(current, alignment, done),
              )
            False -> {
              let proto = case w.pieces {
                [OldPiece(style: st, ..), ..] -> st
                [] -> span.span_plain("")
              }
              let flat = old_word_text(w)
              let #(head, tail) =
                old_split_at_width(flat, width - current_width - gap)
              case head {
                "" -> {
                  let #(row, left) = old_take_row(flat, width)
                  old_pack(
                    old_requeue(left, w.sep, proto, rest),
                    width,
                    alignment,
                    text.cell_width(row),
                    old_push([], row, proto),
                    old_flush(current, alignment, done),
                  )
                }

                _ ->
                  old_pack(
                    old_requeue(tail, w.sep, proto, rest),
                    width,
                    alignment,
                    0,
                    [],
                    old_flush(
                      old_push(old_push_gap(current, w.sep, gap), head, proto),
                      alignment,
                      done,
                    ),
                  )
              }
            }
          }
      }
    }
  }
}

fn old_push_word(current: List(Span), w: OldWord, gap: Int) -> List(Span) {
  let started = old_push_gap(current, w.sep, gap)
  list.fold(w.pieces, started, fn(acc, piece) {
    old_push(acc, piece.content, piece.style)
  })
}

fn old_push_gap(current: List(Span), sep: Span, gap: Int) -> List(Span) {
  case gap {
    0 -> current
    _ -> old_push(current, " ", sep)
  }
}

fn old_requeue(
  left: String,
  sep: Span,
  proto: Span,
  rest: List(OldWord),
) -> List(OldWord) {
  case left {
    "" -> rest
    _ -> [
      OldWord(sep: sep, pieces: [OldPiece(content: left, style: proto)]),
      ..rest
    ]
  }
}

fn old_flush(
  current: List(Span),
  alignment: text.Alignment,
  done: List(Line),
) -> List(Line) {
  case current {
    [] -> done
    _ -> [Line(spans: list.reverse(current), alignment: alignment), ..done]
  }
}

fn old_push(current: List(Span), content: String, proto: Span) -> List(Span) {
  case current {
    [head, ..rest] ->
      case head.style == proto.style && head.link == proto.link {
        True -> [Span(..head, content: head.content <> content), ..rest]
        False -> [Span(..proto, content: content), ..current]
      }
    [] -> [Span(..proto, content: content)]
  }
}

fn old_split_at_width(content: String, budget: Int) -> #(String, String) {
  case budget <= 0 {
    True -> #("", content)
    False -> old_take_cells(string.to_graphemes(content), budget, 0, "")
  }
}

fn old_take_row(content: String, width: Int) -> #(String, String) {
  case string.pop_grapheme(content) {
    Error(Nil) -> #("", "")
    Ok(#(first, rest)) -> {
      let #(more, left) =
        old_split_at_width(rest, width - text.grapheme_cell_width(first))
      #(first <> more, left)
    }
  }
}

fn old_take_cells(
  graphemes: List(String),
  budget: Int,
  used: Int,
  head: String,
) -> #(String, String) {
  case graphemes {
    [] -> #(head, "")
    [g, ..rest] -> {
      let w = text.grapheme_cell_width(g)
      case used + w > budget {
        True -> #(head, string.concat([g, ..rest]))
        False -> old_take_cells(rest, budget, used + w, head <> g)
      }
    }
  }
}
