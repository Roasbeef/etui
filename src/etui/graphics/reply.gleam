//// The terminal's answers to a graphics probe, recognised in input bytes.
////
//// A terminal answers a query by writing into the same stream the keyboard
//// writes into. Unrecognised, a reply is a burst of key presses: the kitty
//// graphics answer `ESC _ G i=31;OK ESC \` would reach an app as `alt+_`,
//// `G`, `i`, `=`, and so on, and a device-attributes answer as a stray `c`.
//// That happens whenever a reply arrives after the probe stopped waiting for
//// it, so this module is used in two places: the probe, which wants the
//// replies, and `etui/input`, which drops any that arrive late.
////
//// Six replies are recognised, each by its own introducer, and each comes from
//// one query in `etui/graphics/probe`:
////
//// | Reply | Bytes | Query |
//// |---|---|---|
//// | `KittyGraphics` | `ESC _ G <keys> ; <message> ESC \` | kitty graphics `a=q` |
//// | `PrimaryAttributes` | `CSI ? <n> ; ... c` | DA1, `CSI c` |
//// | `TerminalVersion` | `ESC P > \| <text> ESC \` | XTVERSION, `CSI > 0 q` |
//// | `CellPixels` | `CSI 6 ; <height> ; <width> t` | `CSI 16 t` |
//// | `WindowPixels` | `CSI 4 ; <height> ; <width> t` | `CSI 14 t` |
//// | `WindowCells` | `CSI 8 ; <rows> ; <columns> t` | `CSI 18 t` |
////
//// None of these introducers is produced by a key. `CSI ? ... c` and
//// `CSI ... t` have no key meaning in any terminal's encoding. `ESC _` and
//// `ESC P` are Alt+underscore and Alt+Shift+P, so those two are taken as a
//// reply only when the bytes that only a reply sends are already there:
//// `G i =` for kitty, whose replies always carry the id the query sent, and
//// `> |` for XTVERSION. A lone Alt+underscore is still a key, and so is
//// Alt+underscore followed by a typed `G`: requiring `G` alone would have
//// taken that pair as the start of a reply and held every later key until
//// the next ESC.
////
//// The recogniser is total. A reply that has the right introducer but a body
//// that does not parse is a `Malformed` value: it is still consumed, because
//// it is not key input, and a caller that only believes positive answers has
//// nothing to do with it.

import gleam/int
import gleam/list
import gleam/result
import gleam/string

const esc = "\u{001B}"

/// One reply from the terminal.
pub type Reply {
  /// The kitty graphics protocol's answer to a command that carried an id:
  /// `message` is `"OK"` on success and an error code and text otherwise.
  KittyGraphics(id: Int, message: String)

  /// The primary device attributes. Every terminal answers this one, which is
  /// why the probe sends it last: once it arrives, every earlier query has
  /// either been answered or will not be.
  PrimaryAttributes(attributes: List(Int))

  /// The terminal's name and version, as it reports them.
  TerminalVersion(text: String)

  /// The size of one cell in pixels.
  CellPixels(width: Int, height: Int)

  /// The size of the text area in pixels.
  WindowPixels(width: Int, height: Int)

  /// The size of the text area in cells.
  WindowCells(columns: Int, rows: Int)

  /// A reply with a recognised introducer and a body that did not parse, kept
  /// whole for diagnostics.
  Malformed(raw: String)
}

/// What the graphemes after one ESC turned out to be.
pub type Recognised {
  /// A complete reply, and the graphemes after it.
  Recognised(reply: Reply, rest: List(String))

  /// The start of a reply whose end has not been read yet. The caller keeps
  /// the ESC and everything after it and tries again with more input.
  Incomplete

  /// Not a reply: the ESC begins a key sequence, or is the Escape key.
  NotAReply
}

/// Recognise a reply in the graphemes that follow an ESC.
///
/// `after_escape` excludes the ESC itself, which is how `etui/input` walks its
/// input. A partial introducer (`_` with nothing after it) is `NotAReply`, so
/// a lone Alt+underscore stays a key; `could_begin` says whether such a
/// prefix might still grow into a reply, for a caller that can afford to wait.
///
/// ## Examples
///
/// ```gleam
/// reply.recognise(string.to_graphemes("[?62;22c"))
/// // -> reply.Recognised(reply.PrimaryAttributes([62, 22]), [])
///
/// reply.recognise(string.to_graphemes("[A"))
/// // -> reply.NotAReply
/// ```
pub fn recognise(after_escape: List(String)) -> Recognised {
  case after_escape {
    // The `i=` is kept as the start of the body, which `kitty_reply` parses.
    ["_", "G", "i", "=", ..body] -> string_reply(body, ["=", "i"], kitty_reply)
    ["P", ">", "|", ..body] -> string_reply(body, [], TerminalVersion)
    ["[", ..body] -> csi_reply(body)
    _ -> NotAReply
  }
}

/// Whether `after_escape` is a proper prefix of a reply introducer, so that
/// more input could still make it one.
///
/// ## Examples
///
/// ```gleam
/// reply.could_begin(["_"])
/// // -> True
/// ```
pub fn could_begin(after_escape: List(String)) -> Bool {
  case after_escape {
    [] | ["_"] | ["_", "G"] | ["_", "G", "i"] | ["P"] | ["P", ">"] -> True
    _ -> False
  }
}

// ─────────────────────────────────────────────────────────────────
// APC and DCS: a string that runs to ST

// APC and DCS bodies end at ST, `ESC \` (ECMA-48 8.3.143). An ESC followed by
// anything else also ends the string, as ECMA-48 has a string cut short by a
// new escape sequence: the body so far is malformed and the ESC starts the
// next sequence, so an unterminated reply cannot swallow the keys after it.
fn string_reply(
  gs: List(String),
  rev_body: List(String),
  build: fn(String) -> Reply,
) -> Recognised {
  case gs {
    [] -> Incomplete
    [g] if g == esc -> Incomplete
    [g, "\\", ..rest] if g == esc -> Recognised(build(join_rev(rev_body)), rest)
    [g, ..] if g == esc -> Recognised(Malformed(join_rev(rev_body)), gs)
    [g, ..rest] -> string_reply(rest, [g, ..rev_body], build)
  }
}

// `i=31;OK`, or `i=31,p=7;ENOENT:file not found`. The keys before the
// semicolon are the ones the command carried; only the id matters here.
// Graphics protocol, "Querying support and available transmission mediums".
fn kitty_reply(body: String) -> Reply {
  {
    use #(keys, message) <- result.try(string.split_once(body, ";"))
    use id <- result.map(kitty_id(string.split(keys, ",")))
    KittyGraphics(id: id, message: message)
  }
  |> result.unwrap(Malformed("G" <> body))
}

fn kitty_id(keys: List(String)) -> Result(Int, Nil) {
  list.find_map(keys, fn(key) {
    case key {
      "i=" <> digits -> int.parse(digits)
      _ -> Error(Nil)
    }
  })
}

// ─────────────────────────────────────────────────────────────────
// CSI replies

fn csi_reply(body: List(String)) -> Recognised {
  case collect_csi(body, []) {
    Error(Nil) -> Incomplete
    Ok(#(params, final, rest)) ->
      case params, final {
        "?" <> attributes, "c" ->
          Recognised(PrimaryAttributes(parse_ints(attributes)), rest)
        _, "t" -> Recognised(window_report(params), rest)
        _, _ -> NotAReply
      }
  }
}

// The three `CSI t` reports carry a selector and two numbers, height before
// width (xterm ctlseqs, "Window manipulation"): 4 is the text area in pixels,
// 6 one cell in pixels, 8 the text area in cells.
fn window_report(params: String) -> Reply {
  case string.split(params, ";") |> list.map(int.parse) {
    [Ok(4), Ok(height), Ok(width)] -> WindowPixels(width: width, height: height)
    [Ok(6), Ok(height), Ok(width)] -> CellPixels(width: width, height: height)
    [Ok(8), Ok(rows), Ok(columns)] -> WindowCells(columns: columns, rows: rows)
    _ -> Malformed("[" <> params <> "t")
  }
}

// A CSI sequence ends at its first byte in 0x40..0x7E, the same rule
// `etui/input` decodes keys by, so the two never disagree about where a
// sequence stops.
fn collect_csi(
  gs: List(String),
  rev_params: List(String),
) -> Result(#(String, String, List(String)), Nil) {
  case gs {
    [] -> Error(Nil)
    [g, ..rest] ->
      case is_final_byte(g) {
        True -> Ok(#(join_rev(rev_params), g, rest))
        False -> collect_csi(rest, [g, ..rev_params])
      }
  }
}

fn is_final_byte(g: String) -> Bool {
  case string.to_utf_codepoints(g) {
    [cp] -> {
      let n = string.utf_codepoint_to_int(cp)
      n >= 0x40 && n <= 0x7E
    }
    _ -> False
  }
}

// DA1 attributes are numbers; anything else in the list is dropped rather
// than failing the reply, because the reply's arrival is what the probe needs
// and its contents are informational.
fn parse_ints(params: String) -> List(Int) {
  string.split(params, ";")
  |> list.filter_map(int.parse)
}

fn join_rev(rev: List(String)) -> String {
  string.concat(list.reverse(rev))
}
