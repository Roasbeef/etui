/// LAB, a bench for everything 2.0 added.
///
/// Run: gleam run -m etui_lab
///
/// Unlike the other dev apps this one does not call `app.run_*`. It opens an
/// `etui/terminal` and drives its own loop, which is the whole point: the loop
/// is ordinary Gleam code you can read, and anything else your program needs to
/// do can sit next to it.
///
/// Each screen states what it is checking and what a correct result looks like,
/// because a screenshot of a TUI is only evidence if you know what to look at.
///
///   1 LAYOUT   the six flex modes and weighted fills
///   2 STYLE    styles that take a modifier away, and the new bits
///   3 INPUT    what the parser makes of what you type
///   4 SCROLL   viewports that hold still, and clicking on a layout
import etui/backend
import etui/buffer
import etui/geometry.{
  type Rect, Fill, FillWeighted, FlexAround, FlexBetween, FlexCenter, FlexEnd,
  FlexEvenly, FlexStart, Horizontal, Length, Percentage, rect_new,
}
import etui/keys
import etui/span
import etui/style
import etui/text
import etui/widgets/block
import etui/widgets/list as list_w
import etui/widgets/paragraph
import etui/widgets/scrollbar
import gleam/int
import gleam/io
import gleam/list
import gleam/string

import etui/backend/default
import etui/terminal

@target(javascript)
import gleam/javascript/promise

// ─────────────────────────────────────────────────────────────────
// Palette

const accent = style.Indexed(51)

const good = style.Indexed(82)

const warn = style.Indexed(214)

const muted = style.Indexed(240)

const bar_bg = style.Indexed(235)

fn plain(s: String) -> span.Span {
  span.span_plain(s)
}

fn tinted(s: String, c: style.Color) -> span.Span {
  span.span_plain(s) |> span.span_fg(c)
}

fn styled(s: String, st: style.Style) -> span.Span {
  span.span_styled(s, st)
}

fn line_at(
  buf: buffer.Buffer,
  x: Int,
  y: Int,
  w: Int,
  spans: List(span.Span),
) -> buffer.Buffer {
  paragraph.render_styled(buf, rect_new(x, y, w, 1), [span.line_new(spans)])
}

// ─────────────────────────────────────────────────────────────────
// Model

pub type Screen {
  Layout
  Styles
  Input
  Scroll
  Prose
}

pub type Model {
  Model(
    screen: Screen,
    /// Which flex mode the LAYOUT screen highlights.
    flex_index: Int,
    /// Weight of the first column on the LAYOUT screen, 1 to 5.
    weight: Int,
    /// Newest first, so the log reads top-down.
    events: List(String),
    /// Text delivered by a bracketed paste, kept whole.
    pasted: String,
    list_state: list_w.ListState,
    /// Where the last mouse press landed, and which pane it hit.
    last_hit: String,
    /// Width the TEXT screen wraps to, so the reflow can be watched.
    prose_width: Int,
    quit: Bool,
  )
}

pub fn initial() -> Model {
  Model(
    screen: Layout,
    flex_index: 0,
    weight: 3,
    events: [],
    pasted: "",
    list_state: list_w.state_new(),
    last_hit: "nothing yet",
    prose_width: 34,
    quit: False,
  )
}

const flex_modes = [
  #("FlexStart", FlexStart),
  #("FlexEnd", FlexEnd),
  #("FlexCenter", FlexCenter),
  #("FlexBetween", FlexBetween),
  #("FlexAround", FlexAround),
  #("FlexEvenly", FlexEvenly),
]

const items = [
  "alpha", "bravo", "charlie", "delta", "echo", "foxtrot", "golf", "hotel",
  "india", "juliet", "kilo", "lima", "mike", "november", "oscar", "papa",
  "quebec", "romeo", "sierra", "tango",
]

// ─────────────────────────────────────────────────────────────────
// Update

pub fn update(event: backend.InputEvent, m: Model) -> Model {
  let logged = Model(..m, events: log(m.events, describe(event)))
  case event {
    backend.KeyPress(k) -> on_key(k, logged)
    backend.Paste(text) -> Model(..logged, pasted: text)
    backend.MousePress(x, y, _) ->
      Model(..logged, last_hit: "press at " <> coords(x, y))
    _ -> logged
  }
}

fn on_key(key: String, m: Model) -> Model {
  case key, m.screen {
    "q", _ -> Model(..m, quit: True)
    "ctrl+c", _ -> Model(..m, quit: True)
    "1", _ -> Model(..m, screen: Layout)
    "2", _ -> Model(..m, screen: Styles)
    "3", _ -> Model(..m, screen: Input)
    "4", _ -> Model(..m, screen: Scroll)
    "5", _ -> Model(..m, screen: Prose)

    // TEXT: narrow and widen the wrap column
    "left", Prose -> Model(..m, prose_width: int.max(8, m.prose_width - 2))
    "right", Prose -> Model(..m, prose_width: int.min(60, m.prose_width + 2))

    // LAYOUT: cycle the highlighted mode, change the weight
    "tab", Layout ->
      Model(..m, flex_index: { m.flex_index + 1 } % list.length(flex_modes))
    "left", Layout -> Model(..m, weight: int.max(1, m.weight - 1))
    "right", Layout -> Model(..m, weight: int.min(5, m.weight + 1))

    // SCROLL: move the selection
    "down", Scroll ->
      Model(
        ..m,
        list_state: list_w.select_next(m.list_state, list.length(items)),
      )
    "up", Scroll -> Model(..m, list_state: list_w.select_prev(m.list_state))
    "j", Scroll ->
      Model(
        ..m,
        list_state: list_w.select_next(m.list_state, list.length(items)),
      )
    "k", Scroll -> Model(..m, list_state: list_w.select_prev(m.list_state))

    _, _ -> m
  }
}

fn log(events: List(String), entry: String) -> List(String) {
  [entry, ..list.take(events, 14)]
}

fn coords(x: Int, y: Int) -> String {
  int.to_string(x) <> "," <> int.to_string(y)
}

/// Every event as the parser produced it. The point of the INPUT screen is
/// that this is not a guess: it is the string your own `case` will match on.
fn describe(event: backend.InputEvent) -> String {
  case event {
    // Both the string the parser produced and what keys.parse makes of it,
    // because the second is the one a `case` should be matching on.
    backend.KeyPress(k) ->
      "KeyPress " <> string.inspect(k) <> "  " <> decoded(k)
    backend.Paste(t) ->
      "Paste "
      <> int.to_string(string.length(t))
      <> " chars, "
      <> int.to_string(list.length(string.split(t, "\n")))
      <> " lines"
    backend.MousePress(x, y, b) -> "MousePress " <> coords(x, y) <> button(b)
    backend.MouseRelease(x, y, b) ->
      "MouseRelease " <> coords(x, y) <> button(b)
    backend.MouseDrag(x, y, b) -> "MouseDrag " <> coords(x, y) <> button(b)
    backend.MouseMove(x, y) -> "MouseMove " <> coords(x, y)
    backend.MouseScroll(x, y, up) ->
      "MouseScroll "
      <> coords(x, y)
      <> case up {
        True -> " up"
        False -> " down"
      }
    backend.Resize(w, h) -> "Resize " <> coords(w, h)
    backend.Tick -> "Tick"
  }
}

/// `keys.parse` in one line: the code, and what was held with it.
fn decoded(raw: String) -> String {
  let event = keys.parse(raw)
  let held = case keys.is_plain(event.modifiers) {
    True -> ""
    False -> " + " <> held_names(event.modifiers)
  }
  "-> " <> code_label(event.code) <> held
}

fn held_names(m: keys.Modifiers) -> String {
  [#(m.ctrl, "ctrl"), #(m.alt, "alt"), #(m.shift, "shift")]
  |> list.filter(fn(pair) { pair.0 })
  |> list.map(fn(pair) { pair.1 })
  |> string.join(",")
}

fn code_label(code: keys.Key) -> String {
  case code {
    keys.Char(c) -> "Char(" <> c <> ")"
    keys.F(n) -> "F(" <> int.to_string(n) <> ")"
    keys.Ctrl(c) -> "Ctrl(" <> c <> ")"
    keys.Alt(c) -> "Alt(" <> c <> ")"
    keys.Unknown(_) -> "Unknown"
    other -> string.inspect(other)
  }
}

fn button(b: backend.MouseButton) -> String {
  case b {
    backend.MouseLeft -> " left"
    backend.MouseMiddle -> " middle"
    backend.MouseRight -> " right"
  }
}

// ─────────────────────────────────────────────────────────────────
// Chrome

fn chrome(buf: buffer.Buffer, m: Model, screen: Rect) -> buffer.Buffer {
  let w = screen.size.width
  let h = screen.size.height
  let tabs =
    list.map(
      [
        #("1 LAYOUT", Layout),
        #("2 STYLE", Styles),
        #("3 INPUT", Input),
        #("4 SCROLL", Scroll),
        #("5 TEXT", Prose),
      ],
      fn(entry) {
        let #(label, which) = entry
        case which == m.screen {
          True ->
            styled(
              " " <> label <> " ",
              style.new(style.Indexed(16), accent, style.bold()),
            )
          False -> tinted(" " <> label <> " ", muted)
        }
      },
    )
  buf
  |> line_at(0, 0, w, tabs)
  |> line_at(0, 1, w, [tinted(string.repeat("─", w), muted)])
  |> line_at(0, h - 1, w, [
    styled(
      text.pad_right(" 1-5 screens   TAB cycle   ←/→ adjust   q quit", w),
      style.new(muted, bar_bg, style.none()),
    ),
  ])
}

fn body(screen: Rect) -> Rect {
  rect_new(0, 2, screen.size.width, int.max(0, screen.size.height - 3))
}

fn heading(
  buf: buffer.Buffer,
  area: Rect,
  title: String,
  check: String,
) -> buffer.Buffer {
  buf
  |> line_at(area.position.x, area.position.y, area.size.width, [
    tinted(title, accent),
  ])
  |> line_at(area.position.x, area.position.y + 1, area.size.width, [
    tinted("look for: ", muted),
    plain(check),
  ])
}

// ─────────────────────────────────────────────────────────────────
// 1 LAYOUT

fn render_layout(buf: buffer.Buffer, m: Model, screen: Rect) -> buffer.Buffer {
  let area = body(screen)
  let buf =
    heading(
      buf,
      area,
      "FLEX MODES",
      "three 6-wide boxes, six arrangements. TAB highlights, ←/→ reweights.",
    )
  let rows =
    geometry.rows(rect_new(
      area.position.x,
      area.position.y + 3,
      area.size.width,
      6,
    ))
  let buf =
    list.index_fold(list.zip(rows, flex_modes), buf, fn(acc, pair, index) {
      let #(row, mode) = pair
      let #(name, flex) = mode
      let label_w = 14
      let strip =
        rect_new(
          row.position.x + label_w,
          row.position.y,
          int.max(0, row.size.width - label_w - 2),
          1,
        )
      let colour = case index == m.flex_index {
        True -> accent
        False -> muted
      }
      let boxes =
        geometry.split_with(
          Horizontal,
          strip,
          [Length(6), Length(6), Length(6)],
          flex,
          1,
        )
      let acc =
        line_at(acc, row.position.x, row.position.y, label_w, [
          tinted(name, colour),
        ])
      list.fold(boxes, acc, fn(b, box) {
        line_at(b, box.position.x, box.position.y, box.size.width, [
          styled("██████", style.default_style() |> style.with_fg(colour)),
        ])
      })
    })

  // Weighted fills: the ratio should read straight off the widths.
  let wrow = rect_new(area.position.x, area.position.y + 10, area.size.width, 3)
  let buf =
    heading(
      buf,
      wrow,
      "WEIGHTED FILL",
      "left column is "
        <> int.to_string(m.weight)
        <> "/"
        <> int.to_string(m.weight + 2)
        <> " of the row; widths are printed so you can check them.",
    )
  let cols =
    geometry.split_h(
      rect_new(wrow.position.x, wrow.position.y + 2, wrow.size.width, 1),
      [FillWeighted(m.weight), FillWeighted(1), FillWeighted(1)],
    )
  list.index_fold(cols, buf, fn(acc, col, i) {
    let shade = case i {
      0 -> accent
      1 -> good
      _ -> warn
    }
    line_at(acc, col.position.x, col.position.y, col.size.width, [
      styled(
        text.pad_right(
          " w="
            <> int.to_string(case i {
            0 -> m.weight
            _ -> 1
          })
            <> " width="
            <> int.to_string(col.size.width),
          col.size.width,
        ),
        style.new(style.Indexed(16), shade, style.none()),
      ),
    ])
  })
}

// ─────────────────────────────────────────────────────────────────
// 2 STYLE
//
// Every row says what it should look like, and prints the escape sequence it
// emitted. If the sample disagrees with the description while the sequence is
// right, that is the terminal's answer, not the library's: several of these
// attributes are widely ignored.

/// The SGR parameters a style emits, e.g. "1" for bold, "6" for rapid blink,
/// "58;5;2" for a green underline. Printed next to each sample so a terminal
/// that ignores an attribute can be told apart from a library that never
/// asked for it.
fn sgr(st: style.Style) -> String {
  let params =
    {
      style.ansi_modifier(st.modifier)
      <> style.ansi_underline_color(st.underline_color)
    }
    |> string.replace("\u{001B}[", " ")
    |> string.replace("m", "")
    |> string.trim
  case params {
    "" -> "-"
    p -> "SGR " <> p
  }
}

fn sample_row(
  buf: buffer.Buffer,
  x: Int,
  y: Int,
  w: Int,
  name: String,
  st: style.Style,
  sample: String,
  expect: String,
) -> buffer.Buffer {
  line_at(buf, x, y, w, [
    tinted(text.pad_right(name, 16), muted),
    styled(text.pad_right(sample, 26), st),
    tinted(text.pad_right(sgr(st), 14), style.Indexed(238)),
    plain(expect),
  ])
}

fn render_styles(buf: buffer.Buffer, screen: Rect) -> buffer.Buffer {
  let area = body(screen)
  let x = area.position.x
  let w = area.size.width
  let base = style.default_style()
  let bold = base |> style.add_modifier(style.bold())

  let buf =
    heading(
      buf,
      area,
      "TAKING A MODIFIER AWAY",
      "the three samples come from one bold style. Only the middle one loses it.",
    )
  let buf =
    buf
    |> line_at(x, area.position.y + 3, w, [
      tinted(text.pad_right("style", 16), style.Indexed(238)),
      tinted(text.pad_right("sample", 26), style.Indexed(238)),
      tinted(text.pad_right("emits", 14), style.Indexed(238)),
      tinted("should look", style.Indexed(238)),
    ])
    |> sample_row(
      x,
      area.position.y + 4,
      w,
      "bold",
      bold,
      "the base style",
      "BOLD",
    )
    |> sample_row(
      x,
      area.position.y + 5,
      w,
      "+ remove(bold)",
      style.patch(bold, base |> style.remove_modifier(style.bold())),
      "bold taken away",
      "PLAIN  <- the new thing",
    )
    |> sample_row(
      x,
      area.position.y + 6,
      w,
      "+ empty",
      style.patch(bold, base),
      "empty overlay",
      "BOLD   <- control, empty means no change",
    )

  let buf =
    heading(
      buf,
      rect_new(x, area.position.y + 8, w, 2),
      "EVERY MODIFIER",
      "a sample that disagrees while its sequence is right is the terminal, not etui.",
    )
  let bits = [
    #("bold", style.bold(), "thicker or brighter"),
    #("dim", style.dim(), "fainter"),
    #("italic", style.italic(), "slanted, often ignored"),
    #("underline", style.underline(), "underlined"),
    #("strikethrough", style.strikethrough(), "struck through"),
    #("reverse", style.reverse(), "colours swapped"),
    #("hidden", style.hidden(), "invisible, cells still reserved"),
    #("blink", style.blink(), "blinking, if the terminal blinks at all"),
    #(
      "rapid_blink",
      style.rapid_blink(),
      "faster blink; almost every terminal ignores it",
    ),
  ]
  let buf =
    list.index_fold(bits, buf, fn(acc, bit, i) {
      let #(name, m, expect) = bit
      sample_row(
        acc,
        x,
        area.position.y + 11 + i,
        w,
        name,
        base |> style.add_modifier(m),
        "sample text",
        expect,
      )
    })

  let buf =
    line_at(buf, x, area.position.y + 21, w, [
      tinted("hidden check  ", muted),
      plain("["),
      styled("SECRET", base |> style.add_modifier(style.hidden())),
      plain("]"),
      tinted("  the brackets must stay six cells apart", muted),
    ])

  // The underline in a colour of its own. SGR 58 is younger than the rest of
  // this screen and a good half of terminals ignore it, so the last row is
  // the control: same colour asked for, no underline turned on, nothing to
  // see. A terminal that draws all four rows the same is telling you it does
  // not implement 58 — the sequence column shows etui asked anyway.
  let underlined = base |> style.add_modifier(style.underline())
  let buf =
    heading(
      buf,
      rect_new(x, area.position.y + 23, w, 2),
      "AN UNDERLINE OF ITS OWN COLOUR",
      "the text stays its colour, the line under it does not. Needs SGR 58.",
    )
  let unders = [
    #("red squiggle", style.Rgb(220, 60, 60), "black text, red line"),
    #("green", style.Indexed(2), "black text, green line"),
    #("default", style.Default, "line takes the text colour"),
  ]
  let buf =
    list.index_fold(unders, buf, fn(acc, u, i) {
      let #(name, colour, expect) = u
      sample_row(
        acc,
        x,
        area.position.y + 26 + i,
        w,
        name,
        underlined |> style.with_underline_color(colour),
        "misspellled word",
        expect,
      )
    })

  sample_row(
    buf,
    x,
    area.position.y + 29,
    w,
    "no underline",
    base |> style.with_underline_color(style.Rgb(220, 60, 60)),
    "misspellled word",
    "PLAIN  <- control, a colour alone draws nothing",
  )
}

// ─────────────────────────────────────────────────────────────────
// 3 INPUT

fn render_input(buf: buffer.Buffer, m: Model, screen: Rect) -> buffer.Buffer {
  let area = body(screen)
  let buf =
    heading(
      buf,
      area,
      "INPUT",
      "every event exactly as the parser produced it.",
    )
  let cols =
    geometry.split_with(
      Horizontal,
      rect_new(
        area.position.x,
        area.position.y + 3,
        area.size.width,
        int.max(0, area.size.height - 3),
      ),
      [FillWeighted(3), FillWeighted(2)],
      FlexStart,
      2,
    )
  case cols {
    [log_col, hint_col] -> {
      let blk =
        block.block_new()
        |> block.with_border(block.Rounded)
        |> block.with_title(" EVENTS ", block.Top)
        |> block.with_colors(muted, style.Default)
      let inner = block.inner(log_col, blk)
      let buf = block.render(buf, log_col, blk)
      let buf =
        list.index_fold(m.events, buf, fn(acc, entry, i) {
          case i < inner.size.height {
            False -> acc
            True -> {
              let shade = case i {
                0 -> accent
                _ -> muted
              }
              line_at(
                acc,
                inner.position.x,
                inner.position.y + i,
                inner.size.width,
                [tinted(text.truncate(entry, inner.size.width, "…"), shade)],
              )
            }
          }
        })

      let hint_blk =
        block.block_new()
        |> block.with_border(block.Rounded)
        |> block.with_title(" TRY ", block.Top)
        |> block.with_colors(muted, style.Default)
      let hint_inner = block.inner(hint_col, hint_blk)
      let buf = block.render(buf, hint_col, hint_blk)
      let tips = [
        #("hold ↓", "one event per repeat, none lost"),
        #("ctrl+→", "Right + ctrl, as data"),
        #("shift+←", "Left + shift, as data"),
        #("paste", "one Paste event, not N keys"),
        #("drag", "MouseDrag, not a run of presses"),
        #("wheel", "MouseScroll up/down"),
        #("resize", "Resize, and the frame follows"),
      ]
      let buf =
        list.index_fold(tips, buf, fn(acc, tip, i) {
          let #(what, expect) = tip
          case i * 2 + 1 < hint_inner.size.height {
            False -> acc
            True ->
              acc
              |> line_at(
                hint_inner.position.x,
                hint_inner.position.y + i * 2,
                hint_inner.size.width,
                [tinted(what, accent)],
              )
              |> line_at(
                hint_inner.position.x + 2,
                hint_inner.position.y + i * 2 + 1,
                int.max(0, hint_inner.size.width - 2),
                [tinted(expect, muted)],
              )
          }
        })

      case m.pasted {
        "" -> buf
        text ->
          line_at(
            buf,
            hint_inner.position.x,
            hint_inner.position.y + hint_inner.size.height - 1,
            hint_inner.size.width,
            [
              tinted("last paste: ", good),
              plain(text.truncate(
                string.replace(text, "\n", "⏎"),
                int.max(0, hint_inner.size.width - 12),
                "…",
              )),
            ],
          )
      }
    }
    _ -> buf
  }
}

// ─────────────────────────────────────────────────────────────────
// 4 SCROLL

fn render_scroll(
  buf: buffer.Buffer,
  m: Model,
  screen: Rect,
  settled: list_w.ListState,
) -> buffer.Buffer {
  let area = body(screen)
  let buf =
    heading(
      buf,
      area,
      "VIEWPORTS THAT HOLD STILL",
      "scroll past the bottom then back up: the window must not move.",
    )
  let panes = scroll_panes(area)
  case panes {
    [list_pane, info_pane] -> {
      let blk = list_block()
      let inner = block.inner(list_pane, blk)
      let widget =
        list_w.list_new(items)
        |> list_w.with_highlight_style(style.new(
          style.Indexed(16),
          accent,
          style.none(),
        ))
      let buf =
        buf
        |> block.render(list_pane, blk)
        |> list_w.render_stateful(inner, widget, settled)
      let sb =
        scrollbar.scrollbar_new(
          list.length(items),
          inner.size.height,
          settled.offset,
        )
        |> scrollbar.with_arrows("", "")
      let buf =
        scrollbar.render_vertical(
          buf,
          rect_new(
            inner.position.x + inner.size.width,
            inner.position.y,
            1,
            inner.size.height,
          ),
          sb,
        )

      let info = block.inner(info_pane, blk)
      buf
      |> block.render(
        info_pane,
        block.block_new()
          |> block.with_border(block.Rounded)
          |> block.with_title(" STATE ", block.Top)
          |> block.with_colors(muted, style.Default),
      )
      |> line_at(info.position.x, info.position.y, info.size.width, [
        tinted("selected  ", muted),
        plain(int.to_string(settled.selected)),
      ])
      |> line_at(info.position.x, info.position.y + 1, info.size.width, [
        tinted("offset    ", muted),
        styled(
          int.to_string(settled.offset),
          style.default_style()
            |> style.with_fg(good),
        ),
      ])
      |> line_at(info.position.x, info.position.y + 2, info.size.width, [
        tinted("rows      ", muted),
        plain(int.to_string(inner.size.height)),
      ])
      |> line_at(info.position.x, info.position.y + 4, info.size.width, [
        tinted("last click", muted),
      ])
      |> line_at(info.position.x, info.position.y + 5, info.size.width, [
        plain(m.last_hit),
      ])
      |> line_at(info.position.x, info.position.y + 7, info.size.width, [
        tinted("click a pane. The rects come out of draw_with,", muted),
      ])
      |> line_at(info.position.x, info.position.y + 8, info.size.width, [
        tinted("so the hit test uses the layout that was drawn.", muted),
      ])
    }
    _ -> buf
  }
}

fn list_block() -> block.Block {
  block.block_new()
  |> block.with_border(block.Rounded)
  |> block.with_title(" 20 ITEMS ", block.Top)
  |> block.with_colors(accent, style.Default)
}

/// The rows the list will actually be given, taken from the layout rather than
/// guessed from the screen height. Guessing happens to agree at some sizes,
/// which is worse than being wrong: it works until it does not.
fn list_rows(screen: Rect) -> Int {
  case scroll_panes(body(screen)) {
    [list_pane, ..] -> block.inner(list_pane, list_block()).size.height
    _ -> 0
  }
}

fn scroll_panes(area: Rect) -> List(Rect) {
  geometry.split_with(
    Horizontal,
    rect_new(
      area.position.x,
      area.position.y + 3,
      area.size.width,
      int.max(0, area.size.height - 3),
    ),
    [Percentage(40), Fill],
    FlexStart,
    2,
  )
}

// ─────────────────────────────────────────────────────────────────
// 5 TEXT

/// One styled sentence. The styles are what has to survive the reflow.
fn prose() -> span.Text {
  span.text_new([
    span.line_new([
      span.span_styled(
        "ERROR",
        style.default_style()
          |> style.with_fg(warn)
          |> style.add_modifier(style.bold()),
      ),
      plain(" the disk holding "),
      span.span_styled(
        "/var/log",
        style.default_style()
          |> style.add_modifier(style.underline()),
      ),
      plain(" filled up while rotating "),
      span.span_styled(
        "etui.log",
        style.default_style()
          |> style.with_fg(accent),
      ),
      plain(", so nothing has been written since."),
    ]),
  ])
}

fn render_prose(buf: buffer.Buffer, m: Model, screen: Rect) -> buffer.Buffer {
  let area = body(screen)
  let x = area.position.x
  let w = area.size.width
  let buf =
    heading(
      buf,
      area,
      "WRAPPING THAT KEEPS THE STYLES",
      "←/→ changes the column. Colours and underline must follow their words.",
    )

  let top = area.position.y + 3
  let column = int.min(m.prose_width, int.max(8, w / 2 - 3))
  let wrapped_area = rect_new(x, top + 1, column, 8)
  let flat_area = rect_new(x + column + 4, top + 1, column, 8)

  let buf =
    buf
    |> line_at(x, top, column, [
      tinted("render_text, width " <> int.to_string(column), accent),
    ])
    |> line_at(x + column + 4, top, column, [
      tinted("render_styled, same width", muted),
    ])
    |> paragraph.render_text(wrapped_area, prose())
    // The same content without wrapping, which is what the old span path did:
    // one row, everything past the edge gone.
    |> paragraph.render_styled(flat_area, prose().lines)

  let checks = area.position.y + 13
  let buf =
    heading(
      buf,
      rect_new(x, checks, w, 2),
      "TEXT THAT USED TO BREAK",
      "each row must be exactly as wide as its label claims.",
    )
  let rows = [
    #("tabs", "a\\tb\\tc expands to 8-column stops", "a\tb\tc"),
    #("CRLF", "a\\r\\nb is two rows, no stray CR", "a\r\nb"),
    #("wide", "four CJK graphemes are eight cells", "漢字漢字"),
  ]
  list.index_fold(rows, buf, fn(acc, entry, i) {
    let #(name, why, sample) = entry
    let y = checks + 3 + i * 2
    let lines = text.wrap(sample, 30)
    let shown = string.join(lines, " ⏎ ")
    acc
    |> line_at(x, y, w, [
      tinted(text.pad_right(name, 8), muted),
      plain(text.pad_right(shown, 22)),
      tinted("cells=" <> int.to_string(text.cell_width(shown)) <> "  ", accent),
      tinted(why, muted),
    ])
  })
}

// ─────────────────────────────────────────────────────────────────
// Render
//
// Returns the panes the SCROLL screen drew, so the loop can match a click
// against the layout that actually reached the terminal rather than one
// recomputed afterwards and hoped to be the same.

pub fn render(m: Model, screen: Rect) -> #(buffer.Buffer, Model, List(Rect)) {
  let base = buffer.buffer_new(screen) |> chrome(m, screen)
  let settled = list_w.settle(m.list_state, list_rows(screen))
  let buf = case m.screen {
    Layout -> render_layout(base, m, screen)
    Styles -> render_styles(base, screen)
    Input -> render_input(base, m, screen)
    Scroll -> render_scroll(base, m, screen, settled)
    Prose -> render_prose(base, m, screen)
  }
  #(buf, Model(..m, list_state: settled), scroll_panes(body(screen)))
}

// ─────────────────────────────────────────────────────────────────
// The loop
//
// This is the part `app.run_*` would have owned. It is twenty lines, and
// everything in it is ordinary code.

fn options() -> backend.Options {
  backend.Options(mouse: True, paste: True)
}

// The loop is written twice because polling is synchronous on Erlang and a
// promise on JavaScript. Everything above this line is shared, which is most
// of the app: only the six lines that wait for an event differ.

@target(erlang)
pub fn main() -> Nil {
  case terminal.new(default.new_with_options(options())) {
    Error(_) -> io.println("could not open the terminal")
    Ok(term) -> {
      terminal.restore(run(term, initial()))
      io.println("lab closed")
    }
  }
}

@target(erlang)
fn run(term: terminal.Terminal(bs), m: Model) -> terminal.Terminal(bs) {
  case draw_frame(term, m) {
    Error(_) -> term
    Ok(#(drawn, settled, panes)) ->
      case terminal.poll(drawn, 30) {
        Error(_) -> drawn
        Ok(#(event, polled)) ->
          case step(settled, event, panes) {
            Ok(next) -> run(polled, next)
            Error(Nil) -> polled
          }
      }
  }
}

@target(javascript)
pub fn main() -> promise.Promise(Nil) {
  case terminal.new(default.new_with_options(options())) {
    Error(_) -> {
      io.println("could not open the terminal")
      promise.resolve(Nil)
    }
    Ok(term) ->
      promise.map(run(term, initial()), fn(final) {
        terminal.restore(final)
        io.println("lab closed")
      })
  }
}

@target(javascript)
fn run(
  term: terminal.Terminal(bs),
  m: Model,
) -> promise.Promise(terminal.Terminal(bs)) {
  case draw_frame(term, m) {
    Error(_) -> promise.resolve(term)
    Ok(#(drawn, settled, panes)) ->
      promise.await(terminal.poll(drawn, 30), fn(result) {
        case result {
          Error(_) -> promise.resolve(drawn)
          Ok(#(event, polled)) ->
            case step(settled, event, panes) {
              Ok(next) -> run(polled, next)
              Error(Nil) -> promise.resolve(polled)
            }
        }
      })
  }
}

/// Draw a frame and carry out the settled model and the panes it laid out.
fn draw_frame(
  term: terminal.Terminal(bs),
  m: Model,
) -> Result(#(terminal.Terminal(bs), Model, List(Rect)), backend.Error) {
  case
    terminal.draw_with(term, fn(frame) {
      let #(buf, settled, panes) = render(m, frame.area)
      #(terminal.with_buffer(frame, buf), #(settled, panes))
    })
  {
    Ok(#(drawn, #(settled, panes))) -> Ok(#(drawn, settled, panes))
    Error(e) -> Error(e)
  }
}

/// One event applied. `Error(Nil)` means the app asked to stop.
fn step(
  m: Model,
  event: backend.InputEvent,
  panes: List(Rect),
) -> Result(Model, Nil) {
  let next = hit_test(update(event, m), event, panes)
  case next.quit {
    True -> Error(Nil)
    False -> Ok(next)
  }
}

// Match a click against the rects the frame actually produced.
fn hit_test(m: Model, event: backend.InputEvent, panes: List(Rect)) -> Model {
  case event {
    backend.MousePress(x, y, _) -> {
      let named = list.zip(["list", "state"], panes)
      let hit =
        list.find(named, fn(entry) {
          let #(_, rect) = entry
          geometry.hit_test(rect, x, y)
        })
      case hit {
        Ok(#(name, _)) ->
          Model(..m, last_hit: name <> " pane at " <> coords(x, y))
        Error(Nil) -> Model(..m, last_hit: "outside both panes")
      }
    }
    _ -> m
  }
}
