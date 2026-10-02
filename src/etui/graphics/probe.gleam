//// Ask the terminal what it can draw, and read the answer.
////
//// The probe is one write and a short read. The write is `query()`: a kitty
//// graphics query for a single pixel, the terminal-version request, the
//// three window-size reports, and last the primary device attributes request
//// (DA1). Terminals answer in the order they were asked, and every terminal
//// answers DA1, so DA1's reply is the end of the answer: whatever has not
//// arrived before it is not coming. That ordering is the kitty protocol's own
//// recommendation (graphics protocol, "Querying support and available
//// transmission mediums"), and it is what keeps the wait short on a terminal
//// that supports nothing.
////
//// Reading is a pure fold over input chunks:
////
//// ```gleam
//// let state = probe.new() |> probe.feed(chunk_one) |> probe.feed(chunk_two)
//// case probe.status(state) {
////   probe.Answered -> probe.capabilities(state)
////   probe.Waiting -> // read more, or give up and take what there is
//// }
//// ```
////
//// Replies may arrive split across reads, interleaved with keys the person
//// typed, or not at all. The fold holds back an incomplete reply until the
//// next chunk, keeps the typed bytes apart (`typed`), and counts a reply only
//// if it arrived before DA1's. `capabilities` can be read at any point, so a
//// caller that runs out of time takes what has arrived, and only positive
//// answers change anything.
////
//// On Erlang `run` does the round trip: raw mode, the write, and the reads up
//// to a deadline the caller chooses.

import etui/graphics.{
  type Capabilities, type CellSize, Capabilities, CellSize, Supported,
  Unsupported,
}
import etui/graphics/reply.{type Reply}
import gleam/list
import gleam/option.{None, Some}
import gleam/string

const esc = "\u{001B}"

/// The image id the one-pixel query carries, so that its reply can be told
/// apart from any other graphics reply. The query action stores nothing, so
/// the id cannot collide with an image the app transmits later.
pub const query_image_id = 31

/// The bytes to write. DA1 comes last; see the module documentation.
///
/// ## Examples
///
/// ```gleam
/// probe.query()
/// // -> "\u{1B}_Gi=31,s=1,v=1,a=q,t=d,f=24;AAAA\u{1B}\\\u{1B}[>0q\u{1B}[16t\u{1B}[14t\u{1B}[18t\u{1B}[c"
/// ```
pub fn query() -> String {
  string.concat([
    // One 24-bit pixel, sent inline (`t=d`), with the query action so the
    // terminal loads it, answers, and keeps nothing. `AAAA` is three zero
    // bytes in base64.
    esc,
    "_Gi=31,s=1,v=1,a=q,t=d,f=24;AAAA",
    esc,
    "\\",
    // XTVERSION. iTerm2 does not answer the graphics query, so its name in
    // this reply is the only positive answer for OSC 1337.
    esc,
    "[>0q",
    // Cell size in pixels, then the window in pixels and in cells for a
    // terminal that answers only those two.
    esc,
    "[16t",
    esc,
    "[14t",
    esc,
    "[18t",
    // DA1, the sentinel.
    esc,
    "[c",
  ])
}

/// Whether the probe has seen the end of the terminal's answer.
pub type Status {
  /// DA1's reply has not arrived. More replies may still come.
  Waiting

  /// DA1's reply has arrived, so every reply that is coming has come.
  Answered
}

/// A probe in progress: the replies so far, the bytes held back as a possibly
/// incomplete reply, and the bytes that were not replies.
pub opaque type Probe {
  Probe(
    status: Status,
    rev_replies: List(Reply),
    pending: List(String),
    rev_typed: List(String),
  )
}

/// A probe that has read nothing.
pub fn new() -> Probe {
  Probe(status: Waiting, rev_replies: [], pending: [], rev_typed: [])
}

/// Fold one chunk of input into the probe.
///
/// A reply split across chunks is completed by the next one. Bytes that are
/// not replies are kept, in order, for `typed`. Replies that arrive after
/// DA1's are consumed and ignored: the probe is over, and they do not count.
///
/// ## Examples
///
/// ```gleam
/// probe.new()
/// |> probe.feed("\u{1B}_Gi=31;OK\u{1B}\\\u{1B}[?6")
/// |> probe.feed("2;22c")
/// |> probe.status
/// // -> probe.Answered
/// ```
pub fn feed(probe: Probe, chunk: String) -> Probe {
  scan(
    Probe(..probe, pending: []),
    list.append(probe.pending, string.to_graphemes(chunk)),
  )
}

/// Whether DA1's reply has arrived.
pub fn status(probe: Probe) -> Status {
  probe.status
}

/// The replies counted so far, oldest first. For diagnostics; an app wants
/// `capabilities`.
pub fn replies(probe: Probe) -> List(Reply) {
  list.reverse(probe.rev_replies)
}

/// The bytes read during the probe that were not replies, which is whatever
/// the person typed while it ran, in order.
pub fn typed(probe: Probe) -> String {
  string.concat(list.reverse(probe.rev_typed))
}

/// What the replies so far say, believing only positive answers.
///
/// - kitty graphics is `Supported` when the query was answered `OK` under
///   `query_image_id` and the terminal-version reply names a terminal that
///   implements Unicode placeholders (`implements_placeholders`). An error
///   message is a terminal that speaks the protocol and could not load the
///   pixel, which is not support.
/// - OSC 1337 is `Supported` when the terminal-version reply starts with
///   `iTerm2`. `TERM_PROGRAM` is never consulted.
/// - The cell size comes from the cell report, or else from the window's
///   pixel size divided by its size in cells. A report of zero, which some
///   terminals send, is no answer.
pub fn capabilities(probe: Probe) -> Capabilities {
  list.fold(list.reverse(probe.rev_replies), graphics.none(), apply)
  |> require_placeholders
  |> fill_cell_size(probe.rev_replies)
}

/// Whether a terminal-version reply names a terminal known to draw kitty
/// images through Unicode placeholder cells: kitty (`kitty(0.39.1)`) and
/// Ghostty (`ghostty 1.2.0`).
///
/// An `OK` to the graphics query proves the protocol, not the placeholders,
/// and etui draws only through placeholders. WezTerm answers `OK` and then
/// ignores `U=1`, drawing the image at the cursor and the placeholder cells
/// as missing glyphs. iTerm2 3.5 also answers `OK`, and it is better served
/// by OSC 1337. So kitty support is believed only for terminals on this
/// list; a terminal that gains placeholders is added here.
///
/// ## Examples
///
/// ```gleam
/// probe.implements_placeholders("ghostty 1.2.0")
/// // -> True
///
/// probe.implements_placeholders("WezTerm 20240203-110809-5046fc22")
/// // -> False
/// ```
pub fn implements_placeholders(xtversion: String) -> Bool {
  string.starts_with(xtversion, "kitty(")
  || string.starts_with(string.lowercase(xtversion), "ghostty")
}

// A kitty `OK` without a terminal-version reply naming a terminal on the
// list is not support: see `implements_placeholders`.
fn require_placeholders(caps: Capabilities) -> Capabilities {
  case caps.terminal {
    Some(name) ->
      case implements_placeholders(name) {
        True -> caps
        False -> Capabilities(..caps, kitty: Unsupported)
      }
    None -> Capabilities(..caps, kitty: Unsupported)
  }
}

fn apply(caps: Capabilities, r: Reply) -> Capabilities {
  case r {
    reply.KittyGraphics(id: id, message: "OK") if id == query_image_id ->
      Capabilities(..caps, kitty: Supported)
    reply.TerminalVersion(text) -> {
      let caps = Capabilities(..caps, terminal: Some(text))
      case string.starts_with(text, "iTerm2") {
        True -> Capabilities(..caps, iterm2: Supported)
        False -> caps
      }
    }
    reply.CellPixels(width: w, height: h) if w > 0 && h > 0 ->
      Capabilities(..caps, cell_size: Some(CellSize(width: w, height: h)))
    _ -> caps
  }
}

// The fallback the cell report leaves open: the text area in pixels over the
// text area in cells, when both arrived and neither was zero.
fn fill_cell_size(
  caps: Capabilities,
  rev_replies: List(Reply),
) -> Capabilities {
  case caps.cell_size {
    Some(_) -> caps
    None ->
      case derived_cell_size(rev_replies) {
        Ok(size) -> Capabilities(..caps, cell_size: Some(size))
        Error(Nil) -> caps
      }
  }
}

fn derived_cell_size(rev_replies: List(Reply)) -> Result(CellSize, Nil) {
  let pixels =
    list.find_map(rev_replies, fn(r) {
      case r {
        reply.WindowPixels(width: w, height: h) if w > 0 && h > 0 -> Ok(#(w, h))
        _ -> Error(Nil)
      }
    })
  let cells =
    list.find_map(rev_replies, fn(r) {
      case r {
        reply.WindowCells(columns: c, rows: r) if c > 0 && r > 0 -> Ok(#(c, r))
        _ -> Error(Nil)
      }
    })
  case pixels, cells {
    Ok(#(w, h)), Ok(#(c, r)) if w >= c && h >= r ->
      Ok(CellSize(width: w / c, height: h / r))
    _, _ -> Error(Nil)
  }
}

// ─────────────────────────────────────────────────────────────────
// The fold

// Walk the graphemes once. Plain bytes are typed input. An ESC is offered to
// the reply recogniser: a reply is recorded (or, after DA1, dropped), an
// incomplete one is held back whole for the next chunk, and anything else is
// typed input that begins with ESC. A bare prefix of an introducer, such as
// `ESC _` at the end of a chunk, is held back too, because only the next
// chunk can say whether it is Alt+underscore or the start of a reply.
fn scan(probe: Probe, gs: List(String)) -> Probe {
  case gs {
    [] -> probe
    [g, ..rest] if g == esc ->
      case reply.recognise(rest) {
        reply.Recognised(r, after) -> scan(record(probe, r), after)
        reply.Incomplete -> Probe(..probe, pending: gs)
        reply.NotAReply ->
          case reply.could_begin(rest) {
            True -> Probe(..probe, pending: gs)
            False ->
              scan(Probe(..probe, rev_typed: [g, ..probe.rev_typed]), rest)
          }
      }
    [g, ..rest] -> scan(Probe(..probe, rev_typed: [g, ..probe.rev_typed]), rest)
  }
}

fn record(probe: Probe, r: Reply) -> Probe {
  case probe.status, r {
    Answered, _ -> probe
    Waiting, reply.PrimaryAttributes(_) ->
      Probe(..probe, status: Answered, rev_replies: [r, ..probe.rev_replies])
    Waiting, _ -> Probe(..probe, rev_replies: [r, ..probe.rev_replies])
  }
}

// ─────────────────────────────────────────────────────────────────
// The round trip, on Erlang

@target(erlang)
type ReadFailure {
  ReadTimeout
  InputClosed
  Woken
}

@target(erlang)
@external(erlang, "etui_terminal_ffi", "enter_raw")
fn enter_raw() -> Nil

@target(erlang)
@external(erlang, "etui_terminal_ffi", "read_with_timeout")
fn read_with_timeout(timeout_ms: Int) -> Result(String, ReadFailure)

@target(erlang)
@external(erlang, "etui_terminal_ffi", "monotonic_ms")
fn monotonic_ms() -> Int

@target(erlang)
@external(erlang, "io", "put_chars")
fn write(bytes: String) -> Nil

@target(erlang)
/// Send the query and read replies until DA1 answers or `timeout_ms` passes,
/// then say what the terminal can draw.
///
/// Call it once, before the backend is opened, from the process that will
/// run the app loop. It puts the terminal in raw mode, because a reply read
/// in cooked mode would be echoed onto the screen and held until a newline,
/// and it leaves raw mode on for the backend, which enters it again as a
/// no-op. Leaving it here would break the app: the runtime starts its raw
/// reader once per session, so after raw mode is left, entering it again
/// leaves the terminal cooked (measured on OTP 29). A caller that probes and
/// then does not open a backend must restore the terminal itself
/// (`stty sane`).
///
/// The keyboard reader started here is the one the backend goes on to use.
/// A reply that arrives after the deadline is therefore read by the backend,
/// where `etui/input` recognises it and drops it rather than delivering it as
/// keys. Two things are lost: a reply cut by a read boundary exactly at the
/// deadline can leave its tail to arrive as keys, since the backend sees it
/// without its introducer, and keys typed during the probe are dropped
/// rather than handed on.
///
/// The deadline is the caller's: a local terminal answers in a few
/// milliseconds, and the wait is only ever spent in full on a terminal that
/// does not answer DA1 at all.
///
/// ## Examples
///
/// ```gleam
/// let caps = probe.run(200)
/// graphics.protocol(caps)
/// ```
pub fn run(timeout_ms: Int) -> Capabilities {
  enter_raw()
  write(query())
  let deadline = monotonic_ms() + timeout_ms
  capabilities(read_until(new(), deadline))
}

@target(erlang)
fn read_until(probe: Probe, deadline: Int) -> Probe {
  let remaining = deadline - monotonic_ms()
  case probe.status, remaining > 0 {
    Answered, _ -> probe
    Waiting, False -> probe
    Waiting, True ->
      case read_with_timeout(remaining) {
        Ok(chunk) -> read_until(feed(probe, chunk), deadline)

        // A wake is another process asking the loop for a tick; the probe
        // has no tick to give, so it keeps waiting for its deadline.
        Error(Woken) -> read_until(probe, deadline)
        Error(ReadTimeout) | Error(InputClosed) -> probe
      }
  }
}
