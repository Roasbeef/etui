/// Terminal style: colors and text modifiers.
/// Supports 16-color (ANSI), 256-color, and RGB (true color).
/// Modifier is a bitfield: modifiers can be freely combined via `add`/`remove`.
import gleam/int
import gleam/string

/// Terminal color. `Default` defers to the terminal theme.
/// `Indexed(n)` covers the whole 256-color space: 0 to 15 are the themeable
/// ANSI colors, 16 to 255 the extended palette (the 6x6x6 cube and the
/// grayscale ramp).
/// `Rgb(r, g, b)` uses 24-bit true color and needs a truecolor terminal.
pub type Color {
  Default
  Indexed(Int)
  Rgb(Int, Int, Int)
}

/// Opaque bitfield for text modifiers. Use constants + `add`/`remove`/`has`.
pub opaque type Modifier {
  Modifier(bits: Int)
}

// ─────────────────────────────────────────────────────────────────
// Modifier constants (bit values)

/// No modifiers active.
pub fn none() -> Modifier {
  Modifier(0)
}

/// Bold / increased intensity.
pub fn bold() -> Modifier {
  Modifier(1)
}

/// Dim / decreased intensity.
pub fn dim() -> Modifier {
  Modifier(2)
}

/// Italic text.
pub fn italic() -> Modifier {
  Modifier(4)
}

/// Underline.
pub fn underline() -> Modifier {
  Modifier(8)
}

/// Blinking text (terminal support varies).
pub fn blink() -> Modifier {
  Modifier(16)
}

/// Swap foreground and background colors.
pub fn reverse() -> Modifier {
  Modifier(32)
}

/// Strikethrough.
pub fn strikethrough() -> Modifier {
  Modifier(64)
}

/// Hidden text: the terminal reserves the cells but draws nothing (SGR 8).
/// Useful for password fields that must keep their layout.
pub fn hidden() -> Modifier {
  Modifier(128)
}

/// Rapid blink (SGR 6). Support is rarer than `blink`, which is SGR 5; a
/// terminal that does not know it usually falls back to the slow one.
pub fn rapid_blink() -> Modifier {
  Modifier(256)
}

// ─────────────────────────────────────────────────────────────────
// Modifier operations

/// Combine two modifiers (bitwise OR).
pub fn add(a: Modifier, b: Modifier) -> Modifier {
  Modifier(int.bitwise_or(a.bits, b.bits))
}

/// Remove modifier bits from `a` that are set in `b`.
pub fn remove(a: Modifier, b: Modifier) -> Modifier {
  Modifier(int.bitwise_and(a.bits, int.bitwise_not(b.bits)))
}

/// Check if `flag` bits are set in `m`.
pub fn has(m: Modifier, flag: Modifier) -> Bool {
  int.bitwise_and(m.bits, flag.bits) != 0
}

/// True when no modifier bits are set.
pub fn is_none(m: Modifier) -> Bool {
  m.bits == 0
}

/// Structural equality for modifiers.
pub fn modifier_equal(a: Modifier, b: Modifier) -> Bool {
  a.bits == b.bits
}

// ─────────────────────────────────────────────────────────────────
// Composite style

/// Combined foreground color, background color, text modifiers, and the
/// colour the underline itself is drawn in.
///
/// A style carries modifiers it turns *on* (`modifier`) and modifiers it turns
/// *off* (`sub_modifier`). The second exists so a style can be laid over
/// another and take something away: a theme that sets bold everywhere and one
/// widget that must not be bold is otherwise impossible to express, because an
/// empty `modifier` in the overlay means "change nothing", not "clear".
///
/// `underline_color` is independent of `fg`: a spell-checker underlines in red
/// under text that stays its own colour. It only shows with the `underline`
/// modifier on, and only on terminals that implement SGR 58 (kitty, VTE,
/// WezTerm, iTerm2); the rest ignore the sequence and draw the underline in
/// the foreground colour, which is the pre-2.0 behaviour.
///
/// Build with `add_modifier` and `remove_modifier` rather than setting the two
/// modifier fields directly; they keep the pair consistent.
pub type Style {
  Style(
    fg: Color,
    bg: Color,
    modifier: Modifier,
    sub_modifier: Modifier,
    underline_color: Color,
  )
}

/// Default style: terminal colors, no modifiers.
pub fn default_style() -> Style {
  Style(
    fg: Default,
    bg: Default,
    modifier: none(),
    sub_modifier: none(),
    underline_color: Default,
  )
}

/// A style from the three things most call sites have on hand.
/// `sub_modifier` is empty and the underline takes the foreground colour;
/// reach for `remove_modifier` and `with_underline_color` for those.
pub fn new(fg: Color, bg: Color, modifier: Modifier) -> Style {
  Style(
    fg: fg,
    bg: bg,
    modifier: modifier,
    sub_modifier: none(),
    underline_color: Default,
  )
}

/// Set foreground color on a style.
pub fn with_fg(s: Style, fg: Color) -> Style {
  Style(..s, fg: fg)
}

/// Set background color on a style.
pub fn with_bg(s: Style, bg: Color) -> Style {
  Style(..s, bg: bg)
}

/// Set modifier on a style.
pub fn with_modifier(s: Style, m: Modifier) -> Style {
  Style(..s, modifier: m)
}

/// Colour the underline separately from the text.
/// Only visible with `underline()` on, and only where SGR 58 is supported.
pub fn with_underline_color(s: Style, c: Color) -> Style {
  Style(..s, underline_color: c)
}

/// Default colors with bold modifier.
pub fn bold_style() -> Style {
  new(Default, Default, bold())
}

/// Default colors with reverse modifier (swap fg/bg).
pub fn reversed() -> Style {
  new(Default, Default, reverse())
}

/// Default colors with italic modifier.
pub fn italic_style() -> Style {
  new(Default, Default, italic())
}

/// Default colors with dim modifier.
pub fn dim_style() -> Style {
  new(Default, Default, dim())
}

/// Default colors with underline modifier.
pub fn underline_style() -> Style {
  new(Default, Default, underline())
}

/// Turn modifiers on. Anything named here stops being turned off.
pub fn add_modifier(s: Style, m: Modifier) -> Style {
  Style(
    ..s,
    modifier: add(s.modifier, m),
    sub_modifier: remove(s.sub_modifier, m),
  )
}

/// Turn modifiers off, including ones a style underneath had turned on.
/// Anything named here stops being turned on.
pub fn remove_modifier(s: Style, m: Modifier) -> Style {
  Style(
    ..s,
    modifier: remove(s.modifier, m),
    sub_modifier: add(s.sub_modifier, m),
  )
}

/// Parse an RGB color from a hex string (`"#RRGGBB"` or `"RRGGBB"`).
/// Returns `Error(Nil)` for malformed input.
///
/// ```gleam
/// style.color_from_hex("#1e1e2e")  // Ok(Rgb(30, 30, 46))
/// style.color_from_hex("ff5555")   // Ok(Rgb(255, 85, 85))
/// ```
pub fn color_from_hex(hex: String) -> Result(Color, Nil) {
  let s = case string.starts_with(hex, "#") {
    True -> string.drop_start(hex, 1)
    False -> hex
  }
  case string.length(s) == 6 {
    False -> Error(Nil)
    True -> {
      let chars = string.to_graphemes(s)
      case chars {
        [r1, r2, g1, g2, b1, b2] ->
          case hex_pair(r1, r2), hex_pair(g1, g2), hex_pair(b1, b2) {
            Ok(r), Ok(g), Ok(b) -> Ok(Rgb(r, g, b))
            _, _, _ -> Error(Nil)
          }
        _ -> Error(Nil)
      }
    }
  }
}

fn hex_pair(hi: String, lo: String) -> Result(Int, Nil) {
  case hex_digit(hi), hex_digit(lo) {
    Ok(h), Ok(l) -> Ok(h * 16 + l)
    _, _ -> Error(Nil)
  }
}

fn hex_digit(c: String) -> Result(Int, Nil) {
  case c {
    "0" -> Ok(0)
    "1" -> Ok(1)
    "2" -> Ok(2)
    "3" -> Ok(3)
    "4" -> Ok(4)
    "5" -> Ok(5)
    "6" -> Ok(6)
    "7" -> Ok(7)
    "8" -> Ok(8)
    "9" -> Ok(9)
    "a" | "A" -> Ok(10)
    "b" | "B" -> Ok(11)
    "c" | "C" -> Ok(12)
    "d" | "D" -> Ok(13)
    "e" | "E" -> Ok(14)
    "f" | "F" -> Ok(15)
    _ -> Error(Nil)
  }
}

/// Apply `over` on top of `base`.
///
/// `Default` colours in `over` fall through to `base`. Modifiers that `over`
/// turns on are added, and modifiers it turns off are taken away, so an
/// overlay can clear something the base had set:
///
/// ```gleam
/// let theme = style.default_style() |> style.add_modifier(style.bold())
/// let quiet = style.default_style() |> style.remove_modifier(style.bold())
/// style.patch(theme, quiet)  // not bold
/// ```
pub fn patch(base: Style, over: Style) -> Style {
  let fg = case over.fg {
    Default -> base.fg
    c -> c
  }
  let bg = case over.bg {
    Default -> base.bg
    c -> c
  }
  let underline_color = case over.underline_color {
    Default -> base.underline_color
    c -> c
  }
  Style(
    fg: fg,
    bg: bg,
    underline_color: underline_color,
    modifier: base.modifier
      |> remove(over.sub_modifier)
      |> add(over.modifier),
    sub_modifier: base.sub_modifier
      |> remove(over.modifier)
      |> add(over.sub_modifier),
  )
}

// ─────────────────────────────────────────────────────────────────
// ANSI sequence generation

/// Foreground color escape sequence.
pub fn ansi_fg(color: Color) -> String {
  case color {
    Default -> ""
    Indexed(0) -> "\u{001B}[30m"
    Indexed(1) -> "\u{001B}[31m"
    Indexed(2) -> "\u{001B}[32m"
    Indexed(3) -> "\u{001B}[33m"
    Indexed(4) -> "\u{001B}[34m"
    Indexed(5) -> "\u{001B}[35m"
    Indexed(6) -> "\u{001B}[36m"
    Indexed(7) -> "\u{001B}[37m"
    Indexed(8) -> "\u{001B}[90m"
    Indexed(9) -> "\u{001B}[91m"
    Indexed(10) -> "\u{001B}[92m"
    Indexed(11) -> "\u{001B}[93m"
    Indexed(12) -> "\u{001B}[94m"
    Indexed(13) -> "\u{001B}[95m"
    Indexed(14) -> "\u{001B}[96m"
    Indexed(15) -> "\u{001B}[97m"
    Indexed(n) -> "\u{001B}[38;5;" <> int.to_string(n) <> "m"
    Rgb(r, g, b) ->
      "\u{001B}[38;2;"
      <> int.to_string(r)
      <> ";"
      <> int.to_string(g)
      <> ";"
      <> int.to_string(b)
      <> "m"
  }
}

/// Background color escape sequence.
pub fn ansi_bg(color: Color) -> String {
  case color {
    Default -> ""
    Indexed(0) -> "\u{001B}[40m"
    Indexed(1) -> "\u{001B}[41m"
    Indexed(2) -> "\u{001B}[42m"
    Indexed(3) -> "\u{001B}[43m"
    Indexed(4) -> "\u{001B}[44m"
    Indexed(5) -> "\u{001B}[45m"
    Indexed(6) -> "\u{001B}[46m"
    Indexed(7) -> "\u{001B}[47m"
    Indexed(8) -> "\u{001B}[100m"
    Indexed(9) -> "\u{001B}[101m"
    Indexed(10) -> "\u{001B}[102m"
    Indexed(11) -> "\u{001B}[103m"
    Indexed(12) -> "\u{001B}[104m"
    Indexed(13) -> "\u{001B}[105m"
    Indexed(14) -> "\u{001B}[106m"
    Indexed(15) -> "\u{001B}[107m"
    Indexed(n) -> "\u{001B}[48;5;" <> int.to_string(n) <> "m"
    Rgb(r, g, b) ->
      "\u{001B}[48;2;"
      <> int.to_string(r)
      <> ";"
      <> int.to_string(g)
      <> ";"
      <> int.to_string(b)
      <> "m"
  }
}

/// Underline colour escape sequence (SGR 58).
///
/// Colon-separated, which is not a style choice. A terminal that does not
/// implement 58 must be able to ignore the whole thing, and with semicolons
/// it cannot: `ESC[58;5;9m` reads as three ordinary parameters — 58 unknown,
/// then 5, then 9 — so asking for a red underline made the text blink and
/// struck it through, and asking for a green one (`58;5;2`) made it blink and
/// go dim. Sub-parameters after a colon belong to the parameter they follow,
/// so `ESC[58:5:9m` is one attribute a terminal either knows or skips.
///
/// The empty field in the RGB form is the colour-space id, which T.416 puts
/// there and every implementation leaves empty.
///
/// `Default` emits nothing rather than SGR 59: a cell is always written after
/// a reset, so there is no stale underline colour to clear.
pub fn ansi_underline_color(color: Color) -> String {
  case color {
    Default -> ""
    // No 16-colour short form exists for the underline, unlike fg and bg:
    // SGR 58 only takes the 5 (indexed) and 2 (rgb) forms.
    Indexed(n) -> "\u{001B}[58:5:" <> int.to_string(n) <> "m"
    Rgb(r, g, b) ->
      "\u{001B}[58:2::"
      <> int.to_string(r)
      <> ":"
      <> int.to_string(g)
      <> ":"
      <> int.to_string(b)
      <> "m"
  }
}

/// Settle a style into what a cell actually shows: modifiers it turns off win
/// over modifiers it turns on, and `sub_modifier` is spent.
///
/// Cells hold resolved styles. Two cells that look identical must compare
/// equal, or the diff repaints them every frame; an unspent `sub_modifier`
/// riding along on a cell would break exactly that.
pub fn resolve(s: Style) -> Style {
  case is_none(s.sub_modifier) {
    True -> s
    False ->
      Style(
        ..s,
        modifier: remove(s.modifier, s.sub_modifier),
        sub_modifier: none(),
      )
  }
}

/// Text modifier escape sequence. Emits all active modifier bits.
pub fn ansi_modifier(m: Modifier) -> String {
  case is_none(m) {
    True -> ""
    False -> {
      let parts = []
      let parts = case has(m, bold()) {
        True -> ["1", ..parts]
        False -> parts
      }
      let parts = case has(m, dim()) {
        True -> ["2", ..parts]
        False -> parts
      }
      let parts = case has(m, italic()) {
        True -> ["3", ..parts]
        False -> parts
      }
      let parts = case has(m, underline()) {
        True -> ["4", ..parts]
        False -> parts
      }
      let parts = case has(m, blink()) {
        True -> ["5", ..parts]
        False -> parts
      }
      let parts = case has(m, reverse()) {
        True -> ["7", ..parts]
        False -> parts
      }
      let parts = case has(m, strikethrough()) {
        True -> ["9", ..parts]
        False -> parts
      }
      let parts = case has(m, hidden()) {
        True -> ["8", ..parts]
        False -> parts
      }
      let parts = case has(m, rapid_blink()) {
        True -> ["6", ..parts]
        False -> parts
      }
      "\u{001B}[" <> string.join(parts, ";") <> "m"
    }
  }
}

/// Reset all styles.
pub fn ansi_reset() -> String {
  "\u{001B}[0m"
}
