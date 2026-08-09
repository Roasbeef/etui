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
    fg: style.Color,
    bg: style.Color,
    modifier: style.Modifier,
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
  Span(
    content: content,
    fg: style.Default,
    bg: style.Default,
    modifier: style.none(),
    link: "",
  )
}

/// Span with explicit style applied.
pub fn span_styled(content: String, s: style.Style) -> Span {
  Span(content: content, fg: s.fg, bg: s.bg, modifier: s.modifier, link: "")
}

/// Span with an OSC 8 clickable hyperlink.
/// Terminals that support OSC 8 (iTerm2, Kitty, VTE, Windows Terminal) will
/// render the text as a clickable link. Others display it as plain text.
///
/// ```gleam
/// span.span_link("docs.gleam.run", "https://docs.gleam.run")
/// ```
pub fn span_link(content: String, uri: String) -> Span {
  Span(
    content: content,
    fg: style.Default,
    bg: style.Default,
    modifier: style.none(),
    link: uri,
  )
}

/// Add an OSC 8 hyperlink URI to an existing span.
pub fn with_link(sp: Span, uri: String) -> Span {
  Span(..sp, link: uri)
}

/// Set foreground color on a span.
pub fn span_fg(sp: Span, color: style.Color) -> Span {
  Span(..sp, fg: color)
}

/// Set background color on a span.
pub fn span_bg(sp: Span, color: style.Color) -> Span {
  Span(..sp, bg: color)
}

/// Add a modifier to a span.
pub fn span_modifier(sp: Span, modifier: style.Modifier) -> Span {
  Span(..sp, modifier: style.add(sp.modifier, modifier))
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
    fg: style.Default,
    bg: style.Default,
    modifier: style.bold(),
    link: "",
  )
}

/// Italic span (default colors + italic modifier).
pub fn span_italic(content: String) -> Span {
  Span(
    content: content,
    fg: style.Default,
    bg: style.Default,
    modifier: style.italic(),
    link: "",
  )
}

/// Dim span (default colors + dim modifier).
pub fn span_dim(content: String) -> Span {
  Span(
    content: content,
    fg: style.Default,
    bg: style.Default,
    modifier: style.dim(),
    link: "",
  )
}

/// Underline span (default colors + underline modifier).
pub fn span_underline(content: String) -> Span {
  Span(
    content: content,
    fg: style.Default,
    bg: style.Default,
    modifier: style.underline(),
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
              sp.fg,
              sp.bg,
              sp.modifier,
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

// A word carries the span it came from, so its style survives being moved.
type Word {
  Word(content: String, style: Span)
}

fn tokenise(spans: List(Span), acc: List(Word)) -> List(Word) {
  case spans {
    [] -> list.reverse(acc)
    [sp, ..rest] -> {
      let words =
        sp.content
        |> string.split(" ")
        |> list.filter(fn(w) { w != "" })
        |> list.map(fn(w) { Word(content: w, style: sp) })
      tokenise(rest, list.append(list.reverse(words), acc))
    }
  }
}

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
      let word_width = text.cell_width(w.content)
      let gap = case current {
        [] -> 0
        _ -> 1
      }
      case current_width + gap + word_width <= width {
        True ->
          pack(
            rest,
            width,
            alignment,
            current_width + gap + word_width,
            push(current, spaced(w.content, gap), w.style),
            done,
          )
        False ->
          case word_width <= width {
            // Starts the next row whole.
            True ->
              pack(
                rest,
                width,
                alignment,
                word_width,
                push([], w.content, w.style),
                flush(current, alignment, done),
              )
            // Wider than any row: break it across rows.
            False -> {
              let #(head, tail) =
                split_at_width(w.content, width - current_width - gap)
              case head {
                "" -> {
                  let #(h2, t2) = split_at_width(w.content, width)
                  pack(
                    [Word(content: t2, style: w.style), ..rest],
                    width,
                    alignment,
                    text.cell_width(h2),
                    push([], h2, w.style),
                    flush(current, alignment, done),
                  )
                }
                _ ->
                  pack(
                    [Word(content: tail, style: w.style), ..rest],
                    width,
                    alignment,
                    0,
                    [],
                    flush(
                      push(current, spaced(head, gap), w.style),
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

fn spaced(content: String, gap: Int) -> String {
  case gap {
    0 -> content
    _ -> " " <> content
  }
}

fn flush(
  current: List(Span),
  alignment: text.Alignment,
  done: List(Line),
) -> List(Line) {
  [Line(spans: list.reverse(current), alignment: alignment), ..done]
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
  a.fg == b.fg && a.bg == b.bg && a.modifier == b.modifier && a.link == b.link
}

// Take as many graphemes as fit in `budget` cells.
fn split_at_width(content: String, budget: Int) -> #(String, String) {
  case budget <= 0 {
    True -> #("", content)
    False -> take_cells(string.to_graphemes(content), budget, 0, "")
  }
}

fn take_cells(
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
        False -> take_cells(rest, budget, used + w, head <> g)
      }
    }
  }
}
