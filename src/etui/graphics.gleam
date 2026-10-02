//// Inline images: what the terminal can draw, and how big to draw it.
////
//// Three terminal protocols put pixels on a character grid, and none of them
//// can be assumed. kitty and Ghostty implement the kitty graphics protocol,
//// iTerm2 implements its own OSC 1337, and most terminals implement neither
//// and print whatever they do not understand. A terminal also cannot be
//// identified from the environment: `TERM_PROGRAM` survives `ssh`, tmux and
//// terminal multiplexers that cannot pass graphics through. So an app asks the
//// terminal, once at launch, and believes only a positive answer.
////
//// The work is split by what it touches:
////
//// | Module | Does |
//// |---|---|
//// | `etui/graphics` | the answer (`Capabilities`), the protocol to use, the env checks, and fitting an image to a cell box |
//// | `etui/graphics/reply` | recognising the terminal's replies in input bytes, so they never reach an app as keys |
//// | `etui/graphics/probe` | the query, a parser that turns replies into `Capabilities`, and on Erlang the round trip itself |
//// | `etui/graphics/kitty` | transmit, virtual placement, deletion, and the Unicode placeholder cells |
//// | `etui/graphics/iterm2` | OSC 1337 inline images, the fallback |
////
//// All of it except `probe.run` is pure and runs on both targets. None of it
//// decodes pixels: the terminal does that, and an app that wants the image's
//// dimensions for `fit` reads them from the file's header itself.
////
//// ## Launch order
////
//// ```gleam
//// let caps = case graphics.decide(env.get) {
////   graphics.Probe -> probe.run(200)
////   graphics.Skip(_) -> graphics.none()
//// }
//// // then open the backend, which enters the alternate screen
//// ```
////
//// The probe runs before the alternate screen because its replies are read
//// in raw mode and must not be drawn, and because the answer decides how the
//// first frame is laid out.

import gleam/option.{type Option, None}

// ─────────────────────────────────────────────────────────────────
// What the terminal said

/// Whether the terminal answered positively for one protocol.
///
/// Two variants rather than a `Bool`, so that a field reads as the answer it
/// holds: `caps.kitty == Supported`.
pub type Support {
  /// The terminal answered the query for this protocol with a success.
  Supported

  /// No answer, a refusal, or an answer that arrived too late to count.
  Unsupported
}

/// The size of one character cell in pixels.
pub type CellSize {
  CellSize(width: Int, height: Int)
}

/// What a probe learned about the terminal, read once at launch.
///
/// Every field starts from "no" and is changed only by a positive reply, so a
/// terminal that says nothing, a multiplexer that swallows the query, and a
/// probe that timed out all produce `none()`.
pub type Capabilities {
  Capabilities(
    /// The kitty graphics protocol: a one-pixel query was answered `OK`
    /// before the primary device attributes reply.
    kitty: Support,
    /// OSC 1337 inline images: the terminal-version reply names iTerm2.
    iterm2: Support,
    /// The pixel size of one cell, from `CSI 16 t`, or from `CSI 14 t` over
    /// `CSI 18 t` when the terminal answers only the window sizes.
    cell_size: Option(CellSize),
    /// The terminal's own name and version, from `XTVERSION`, as sent.
    terminal: Option(String),
  )
}

/// The answer for a terminal that was not asked, or did not answer.
///
/// ## Examples
///
/// ```gleam
/// graphics.protocol(graphics.none())
/// // -> graphics.TextOnly
/// ```
pub fn none() -> Capabilities {
  Capabilities(
    kitty: Unsupported,
    iterm2: Unsupported,
    cell_size: None,
    terminal: None,
  )
}

/// The protocol an app should draw with.
pub type Protocol {
  /// Transmit with `etui/graphics/kitty` and draw placeholder cells.
  Kitty

  /// Draw with `etui/graphics/iterm2` after each frame that moves the box.
  Iterm2

  /// No images: draw the app's text placeholder instead.
  TextOnly
}

/// Pick the protocol to use from what the terminal said.
///
/// kitty wins when both answered, because its placeholder cells are text: the
/// frame differ moves and clips them like any other cell, where an OSC 1337
/// image has to be redrawn by hand whenever its box moves.
///
/// ## Examples
///
/// ```gleam
/// graphics.protocol(graphics.Capabilities(..graphics.none(), kitty: graphics.Supported))
/// // -> graphics.Kitty
/// ```
pub fn protocol(caps: Capabilities) -> Protocol {
  case caps.kitty, caps.iterm2 {
    Supported, _ -> Kitty
    Unsupported, Supported -> Iterm2
    Unsupported, Unsupported -> TextOnly
  }
}

// ─────────────────────────────────────────────────────────────────
// Whether to ask at all

/// Why a probe should not be sent.
pub type SkipReason {
  /// `HERDR_ENV` is set. Herdr does not pass pane graphics through (it removed
  /// its pane-graphics API in 0.9.3), and the query bytes would reach a pane
  /// that cannot answer them.
  InsideHerdr

  /// `NO_COLOR` is set to a non-empty value. An image is colour, and the
  /// person asked for none.
  ColourDisabled
}

/// What to do before the alternate screen.
pub type Decision {
  /// Send the query and read the replies.
  Probe

  /// Do not ask; use `none()`.
  Skip(reason: SkipReason)
}

/// Decide from the environment whether a probe is worth sending.
///
/// `getenv` is the caller's environment lookup, so this stays pure and the
/// caller keeps any rule of its own (a plain palette, a config switch) in
/// front of it.
///
/// tmux is deliberately not a reason to skip. tmux answers the device
/// attributes and version requests itself and drops the graphics query unless
/// passthrough is on, so asking costs one round trip and the answer is
/// correctly "no"; if a future tmux passes the query through and the terminal
/// answers, the answer is believed.
///
/// ## Examples
///
/// ```gleam
/// graphics.decide(fn(name) {
///   case name {
///     "HERDR_ENV" -> Ok("1")
///     _ -> Error(Nil)
///   }
/// })
/// // -> graphics.Skip(graphics.InsideHerdr)
/// ```
pub fn decide(getenv: fn(String) -> Result(String, Nil)) -> Decision {
  case getenv("HERDR_ENV"), getenv("NO_COLOR") {
    Ok(_), _ -> Skip(InsideHerdr)

    // no-color.org: the variable counts when it is present and not empty.
    Error(Nil), Ok(value) if value != "" -> Skip(ColourDisabled)
    Error(Nil), _ -> Probe
  }
}

// ─────────────────────────────────────────────────────────────────
// Fitting an image to cells

/// A rectangle of character cells an image is drawn into.
pub type Box {
  Box(columns: Int, rows: Int)
}

/// The cell box that shows an image whole, at its natural size if that fits
/// and scaled down to fit `max` otherwise, with its aspect ratio kept.
///
/// An image is never scaled up: a 16-pixel icon stays one or two cells wide.
/// Both dimensions round up, so the box always covers the image and the
/// terminal, which fits the image inside the box, never crops it. A box is at
/// least one cell each way unless `max` has no room at all, and a malformed
/// input (a zero or negative size) asks for a single cell rather than failing.
///
/// ## Examples
///
/// ```gleam
/// // 1200x700 pixels into at most 60x12 cells of 10x20 pixels.
/// graphics.fit(1200, 700, graphics.CellSize(10, 20), graphics.Box(60, 12))
/// // -> graphics.Box(columns: 42, rows: 12)
/// ```
pub fn fit(
  image_width: Int,
  image_height: Int,
  cell: CellSize,
  max: Box,
) -> Box {
  case max.columns < 1 || max.rows < 1 {
    True -> Box(columns: 0, rows: 0)
    False ->
      case
        image_width < 1 || image_height < 1 || cell.width < 1 || cell.height < 1
      {
        True -> Box(columns: 1, rows: 1)
        False -> fit_within(image_width, image_height, cell, max)
      }
  }
}

fn fit_within(w: Int, h: Int, cell: CellSize, max: Box) -> Box {
  let natural =
    Box(columns: ceil_div(w, cell.width), rows: ceil_div(h, cell.height))
  case natural.columns <= max.columns && natural.rows <= max.rows {
    True -> natural
    False -> {
      // Fill the width first and derive the rows from the aspect ratio. Rows
      // are `h / w` of the box's pixel width, measured in cell heights, which
      // is `h * columns * cell.width / (w * cell.height)` in integers.
      let rows_at_full_width =
        ceil_div(h * max.columns * cell.width, w * cell.height)
      case rows_at_full_width <= max.rows {
        True ->
          Box(columns: max.columns, rows: at_least_one(rows_at_full_width))

        // Too tall at full width, so the height is the limit instead.
        False ->
          Box(
            columns: at_least_one(ceil_div(
              w * max.rows * cell.height,
              h * cell.width,
            )),
            rows: max.rows,
          )
      }
    }
  }
}

fn ceil_div(n: Int, d: Int) -> Int {
  { n + d - 1 } / d
}

fn at_least_one(n: Int) -> Int {
  case n < 1 {
    True -> 1
    False -> n
  }
}
