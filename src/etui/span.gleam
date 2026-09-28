/// Styled text spans: inline mixed-style text for TUI widgets.
///
/// A `Span` is a styled text fragment. A `Line` is a list of spans
/// rendered left-to-right on a single terminal row. Use `render_line`
/// to draw a `Line` into a buffer at a given position.
///
/// Example:
/// ```gleam
/// let line = line_new([
///   span_styled("ERROR", style.bold_style() |> style.with_fg(style.Rgb(255,0,0))),
///   span_plain(" file not found"),
/// ])
/// span.render_line(buf, pos, line, 40)
/// ```
import etui/buffer
import etui/geometry
import etui/style
import etui/text
import gleam/int
import gleam/list
import gleam/string

// ─────────────────────────────────────────────────────────────────
// Types

/// A styled text fragment: string content + display style + optional hyperlink.
pub type Span {
  Span(
    content: String,
    style: style.Style,
    /// OSC 8 hyperlink URI. Empty string = no link.
    link: String,
  )
}

/// A single terminal row composed of styled spans.
pub type Line {
  Line(spans: List(Span), alignment: text.Alignment)
}

/// Several lines of styled text.
///
/// `Line` is one row and never wraps; `Text` is a block that does. Until this
/// existed, wrapping only worked on a plain `String`, so any text that needed
/// both mixed styles and reflowing, a log viewer or rendered markdown, could
/// not have both.
pub type Text {
  Text(lines: List(Line))
}

// ─────────────────────────────────────────────────────────────────
// Constructors

/// Span with default terminal colors and no modifier.
pub fn span_plain(content: String) -> Span {
  Span(content: content, style: style.default_style(), link: "")
}

/// Span with explicit style applied.
pub fn span_styled(content: String, s: style.Style) -> Span {
  Span(content: content, style: s, link: "")
}

/// Span with an OSC 8 clickable hyperlink.
/// Terminals that support OSC 8 (iTerm2, Kitty, VTE, Windows Terminal) will
/// render the text as a clickable link. Others display it as plain text.
///
/// ```gleam
/// span.span_link("docs.gleam.run", "https://docs.gleam.run")
/// ```
pub fn span_link(content: String, uri: String) -> Span {
  Span(content: content, style: style.default_style(), link: uri)
}

/// Add an OSC 8 hyperlink URI to an existing span.
pub fn with_link(sp: Span, uri: String) -> Span {
  Span(..sp, link: uri)
}

/// Set foreground color on a span.
pub fn span_fg(sp: Span, color: style.Color) -> Span {
  Span(..sp, style: style.with_fg(sp.style, color))
}

/// Set background color on a span.
pub fn span_bg(sp: Span, color: style.Color) -> Span {
  Span(..sp, style: style.with_bg(sp.style, color))
}

/// Add a modifier to a span.
pub fn span_modifier(sp: Span, modifier: style.Modifier) -> Span {
  Span(..sp, style: style.add_modifier(sp.style, modifier))
}

/// Colour the underline of a span independently of its text.
pub fn span_underline_color(sp: Span, color: style.Color) -> Span {
  Span(..sp, style: style.with_underline_color(sp.style, color))
}

/// Total cell width of a span.
pub fn span_width(sp: Span) -> Int {
  text.cell_width(sp.content)
}

/// Line from a list of spans, left-aligned.
pub fn line_new(spans: List(Span)) -> Line {
  Line(spans: spans, alignment: text.Left)
}

/// Line with a single unstyled string, left-aligned.
pub fn line_plain(content: String) -> Line {
  Line(spans: [span_plain(content)], alignment: text.Left)
}

/// Line from spans with explicit alignment.
pub fn line_aligned(spans: List(Span), alignment: text.Alignment) -> Line {
  Line(spans: spans, alignment: alignment)
}

/// Bold span (default colors + bold modifier).
pub fn span_bold(content: String) -> Span {
  Span(
    content: content,
    style: style.new(style.Default, style.Default, style.bold()),
    link: "",
  )
}

/// Italic span (default colors + italic modifier).
pub fn span_italic(content: String) -> Span {
  Span(
    content: content,
    style: style.new(style.Default, style.Default, style.italic()),
    link: "",
  )
}

/// Dim span (default colors + dim modifier).
pub fn span_dim(content: String) -> Span {
  Span(
    content: content,
    style: style.new(style.Default, style.Default, style.dim()),
    link: "",
  )
}

/// Underline span (default colors + underline modifier).
pub fn span_underline(content: String) -> Span {
  Span(
    content: content,
    style: style.new(style.Default, style.Default, style.underline()),
    link: "",
  )
}

/// Total cell width of a line (sum of span widths).
pub fn line_width(l: Line) -> Int {
  list.fold(l.spans, 0, fn(acc, sp) { acc + span_width(sp) })
}

// ─────────────────────────────────────────────────────────────────
// Rendering

/// Render a line into the buffer at `pos`, clipped to `max_width` cells.
/// Each span is drawn with its own fg/bg/modifier. Spans beyond max_width
/// are silently dropped; a span that straddles the boundary is truncated.
/// The line's `alignment` field shifts the start position within the available width.
pub fn render_line(
  buf: buffer.Buffer,
  pos: geometry.Position,
  l: Line,
  max_width: Int,
) -> buffer.Buffer {
  case max_width <= 0 {
    True -> buf
    False -> {
      let content_width = line_width(l)
      let offset = case l.alignment {
        text.Left -> 0
        text.Right -> int.max(0, max_width - content_width)
        text.Center -> int.max(0, { max_width - content_width } / 2)
      }
      let start_x = pos.x + offset
      render_spans(buf, pos, l.spans, start_x, pos.x + max_width)
    }
  }
}

fn render_spans(
  buf: buffer.Buffer,
  pos: geometry.Position,
  spans: List(Span),
  x: Int,
  x_end: Int,
) -> buffer.Buffer {
  case spans {
    [] -> buf
    [sp, ..rest] -> {
      case x >= x_end {
        True -> buf
        False -> {
          let avail = x_end - x
          let content = text.truncate(sp.content, avail, "")
          let w = text.cell_width(content)
          let buf2 =
            buffer.set_string_linked(
              buf,
              geometry.Position(x: x, y: pos.y),
              content,
              sp.style,
              sp.link,
            )
          render_spans(buf2, pos, rest, x + w, x_end)
        }
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────
// Wrapping

/// Text from a single unstyled string, split on newlines.
pub fn text_plain(content: String) -> Text {
  Text(
    lines: content
    |> text.normalise_newlines
    |> string.split("\n")
    |> list.map(line_plain),
  )
}

/// Text from lines.
pub fn text_new(lines: List(Line)) -> Text {
  Text(lines: lines)
}

/// Total rows.
pub fn text_height(t: Text) -> Int {
  list.length(t.lines)
}

/// Wrap every line to `width` cells, keeping each span's style.
///
/// ```gleam
/// span.line_new([span.span_bold("ERROR"), span.span_plain(" disk full")])
/// |> span.text_new([_])
/// |> span.wrap(12)
/// // ERROR disk   <- still bold
/// // full
/// ```
pub fn wrap(t: Text, width: Int) -> Text {
  case width <= 0 {
    True -> Text(lines: [])
    False -> Text(lines: list.flat_map(t.lines, wrap_line(_, width)))
  }
}

/// Wrap one line into as many as it takes.
///
/// Words are the unit, as in `text.wrap`, and a word wider than the line is
/// broken across rows rather than left to overflow. A word never loses its
/// style by being moved to another row, which is the whole point: the styles
/// travel with the words rather than with the columns they happened to be in.
///
/// A row always takes at least one grapheme. When a single grapheme is wider
/// than `width` (a CJK character or an emoji at a width of 1), it gets a row
/// to itself and that row is wider than asked, by that grapheme's excess and
/// no more. The alternative, taking nothing, never finishes.
pub fn wrap_line(l: Line, width: Int) -> List(Line) {
  case width <= 0 {
    True -> []
    False ->
      case tokenise(l.spans, []) {
        // An empty line stays one empty line rather than vanishing.
        [] -> [Line(spans: [], alignment: l.alignment)]
        words -> pack(words, width, l.alignment, 0, [], [])
      }
  }
}

// A word, which may be made of pieces from more than one span: "etui.log"
// styled one way followed immediately by "," styled another is a single word
// and must never be split by the wrapper.
//
// Splitting each span on spaces independently and rejoining with spaces put a
// space between those two, inventing whitespace the source never had.
type Piece {
  Piece(content: String, style: Span)
}

// `sep` is the style of the space that preceded this word in the source. The
// wrapper drops that space at a line break and re-emits it between words on
// the same row, and it has to come back styled as it was: an unstyled space
// punches a hole in a highlighted run, and a space that borrows the next
// word's style draws that word's underline one cell early.
type Word {
  Word(sep: Span, pieces: List(Piece))
}

fn word_width(w: Word) -> Int {
  list.fold(w.pieces, 0, fn(acc, p) { acc + text.cell_width(p.content) })
}

fn word_text(w: Word) -> String {
  string.concat(list.map(w.pieces, fn(p) { p.content }))
}

fn tokenise(spans: List(Span), acc: List(Word)) -> List(Word) {
  let blank = span_plain("")
  let #(words, pending, pending_sep) = tokenise_loop(spans, [], blank, [])
  let all = case pending {
    [] -> words
    _ -> [Word(sep: pending_sep, pieces: list.reverse(pending)), ..words]
  }
  let _ = acc
  list.reverse(all)
}

// `pending` is the word being built, newest piece first. A span boundary only
// ends a word when there is a space at it.
fn tokenise_loop(
  spans: List(Span),
  pending: List(Piece),
  pending_sep: Span,
  done: List(Word),
) -> #(List(Word), List(Piece), Span) {
  case spans {
    [] -> #(done, pending, pending_sep)
    [sp, ..rest] -> {
      let #(next_pending, next_sep, next_done) =
        absorb(
          string.split(sp.content, " "),
          sp,
          pending,
          pending_sep,
          done,
          True,
        )
      tokenise_loop(rest, next_pending, next_sep, next_done)
    }
  }
}

fn absorb(
  parts: List(String),
  sp: Span,
  pending: List(Piece),
  pending_sep: Span,
  done: List(Word),
  first: Bool,
) -> #(List(Piece), Span, List(Word)) {
  case parts {
    [] -> #(pending, pending_sep, done)
    [part, ..rest] -> {
      // Every part after the first was preceded by a space, so it starts a new
      // word; the first one continues whatever was already being built. That
      // space came out of `sp`, and the word now starting is the one that has
      // to carry it back.
      let #(carry, carry_sep, closed) = case first {
        True -> #(pending, pending_sep, done)
        False ->
          case pending {
            [] -> #([], sp, done)
            _ -> #([], sp, [
              Word(sep: pending_sep, pieces: list.reverse(pending)),
              ..done
            ])
          }
      }
      let grown = case part {
        "" -> carry
        _ -> [Piece(content: part, style: sp), ..carry]
      }
      absorb(rest, sp, grown, carry_sep, closed, False)
    }
  }
}

// Lay words into rows no wider than `width`, with one exception.
//
// Every call consumes one word, and a word wider than any row is broken by
// `break_rows` in the same call rather than put back on the queue piece by
// piece. `break_rows` rests on a single rule: a fresh row always takes at least
// one grapheme, even one wider than the row. Without it, a 2-cell grapheme at a
// width of 1 fits nowhere and the word never shrinks. With it, the only row
// that can exceed `width` is one holding a single grapheme wider than the row,
// since nothing is ever packed after it.
fn pack(
  words: List(Word),
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
      let this_width = word_width(w)
      let gap = case current {
        [] -> 0
        _ -> 1
      }
      case current_width + gap + this_width <= width {
        True ->
          pack(
            rest,
            width,
            alignment,
            current_width + gap + this_width,
            push_word(current, w, gap),
            done,
          )
        False ->
          case this_width <= width {
            // Starts the next row whole.
            True ->
              pack(
                rest,
                width,
                alignment,
                this_width,
                push_word([], w, 0),
                flush(current, alignment, done),
              )
            // Wider than any row: break it across rows. A word this long is
            // treated as one style, its first, rather than tracking where each
            // piece falls inside the break.
            False -> {
              let proto = case w.pieces {
                [Piece(style: st, ..), ..] -> st
                [] -> span_plain("")
              }
              let graphemes = string.to_graphemes(word_text(w))
              let #(head, _, left) =
                take_fitting(graphemes, width - current_width - gap, 0, [])

              // The word's graphemes are split into rows in one pass. Measuring
              // and re-joining the rest of the word for every row, as this
              // once did by requeueing the remainder as a new word, made a long
              // unbroken run cost time quadratic in its length.
              let #(started, remaining) = case head {
                // Nothing fits in what is left of this row, so the word
                // starts a fresh one.
                [] -> #(flush(current, alignment, done), graphemes)

                // Part of the word fills out this row, behind the space that
                // preceded it, and the rest starts the next one.
                _ -> #(
                  flush(
                    push(push_gap(current, w.sep, gap), join(head), proto),
                    alignment,
                    done,
                  ),
                  left,
                )
              }

              // Every row but the last is closed here. The last stays open,
              // so the next word can join it when there is room.
              let #(closed, last, last_width) =
                break_rows(remaining, width, proto, alignment, started)
              let open = case last {
                "" -> []
                _ -> push([], last, proto)
              }
              pack(rest, width, alignment, last_width, open, closed)
            }
          }
      }
    }
  }
}

// Push a whole word, piece by piece, so each keeps its own style.
fn push_word(current: List(Span), w: Word, gap: Int) -> List(Span) {
  let started = push_gap(current, w.sep, gap)
  list.fold(w.pieces, started, fn(acc, piece) {
    push(acc, piece.content, piece.style)
  })
}

fn push_gap(current: List(Span), sep: Span, gap: Int) -> List(Span) {
  case gap {
    0 -> current
    _ -> push(current, " ", sep)
  }
}

// Close the row being built. A row with nothing in it is not emitted: the only
// way to get here empty is a word whose first grapheme is wider than the whole
// row, and that word opens the next row itself.
fn flush(
  current: List(Span),
  alignment: text.Alignment,
  done: List(Line),
) -> List(Line) {
  case current {
    [] -> done
    _ -> [Line(spans: list.reverse(current), alignment: alignment), ..done]
  }
}

// Append to the span being built when the style matches, so a wrapped line
// does not come back as one span per word.
fn push(current: List(Span), content: String, proto: Span) -> List(Span) {
  case current {
    [head, ..rest] ->
      case same_style(head, proto) {
        True -> [Span(..head, content: head.content <> content), ..rest]
        False -> [Span(..proto, content: content), ..current]
      }
    [] -> [Span(..proto, content: content)]
  }
}

fn same_style(a: Span, b: Span) -> Bool {
  a.style == b.style && a.link == b.link
}

// Take graphemes from the front of `graphemes` while they fit in `budget`
// cells, `used` of which are already spent. Returns what was taken, newest
// first, the cells used, and what is left.
//
// This may take nothing, which is right for the tail end of a row that is
// already partly full. A budget of zero or less takes nothing at all, not even
// a zero-width grapheme.
fn take_fitting(
  graphemes: List(String),
  budget: Int,
  used: Int,
  taken: List(String),
) -> #(List(String), Int, List(String)) {
  case graphemes {
    [] -> #(taken, used, [])
    [g, ..rest] -> {
      let w = text.grapheme_cell_width(g)
      case budget > 0 && used + w <= budget {
        True -> take_fitting(rest, budget, used + w, [g, ..taken])
        False -> #(taken, used, graphemes)
      }
    }
  }
}

// Split the rest of a broken word into rows of `width` cells, closing each one
// onto `done` except the last, which comes back with its width so the caller
// can keep it open.
//
// Every row takes its first grapheme unconditionally and then fills up to
// `width` cells. A fresh row that took nothing would never finish; this way, a
// grapheme wider than the row gets a row to itself, since nothing else fits
// after it. A zero-width grapheme still fits in a row that is exactly full, so
// it stays on the row with the grapheme before it.
//
// Each grapheme is measured once and each row joined once, so the whole word
// costs time linear in its length.
fn break_rows(
  graphemes: List(String),
  width: Int,
  proto: Span,
  alignment: text.Alignment,
  done: List(Line),
) -> #(List(Line), String, Int) {
  case graphemes {
    [] -> #(done, "", 0)
    [first, ..rest] -> {
      let first_width = text.grapheme_cell_width(first)
      let #(taken, used, left) = take_fitting(rest, width, first_width, [first])
      let row = join(taken)

      case left {
        [] -> #(done, row, used)
        _ ->
          break_rows(left, width, proto, alignment, [
            Line(spans: [Span(..proto, content: row)], alignment: alignment),
            ..done
          ])
      }
    }
  }
}

// Join graphemes collected newest first.
fn join(taken: List(String)) -> String {
  string.concat(list.reverse(taken))
}
