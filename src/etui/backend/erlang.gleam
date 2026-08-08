/// Erlang/BEAM terminal backend with true raw mode.
/// Uses native Erlang modules for terminal control (inspired by Etch).
import etui/backend.{
  type Error, type InputEvent, type RenderOp, type TerminalSize, ClearScreen,
  DisableBracketedPaste, DisableMouse, EnableBracketedPaste, EnableMouse,
  EnterAltScreen, ExitAltScreen, IOError, MoveCursor, Write,
}
import etui/input
import gleam/int
import gleam/list

// ─────────────────────────────────────────────────────────────────
// Types

pub type ErlangTerminalState {
  ErlangTerminalState(
    raw_mode_active: Bool,
    cols: Int,
    rows: Int,
    mouse: Bool,
    /// Monotonic ms at the last `window_size_ffi` call.
    last_size_check: Int,
    /// Monotonic ms at the last size that actually differed. Drives the
    /// active/idle poll rate, see `resize_settle_ms`.
    last_size_change: Int,
    /// Bytes read but not yet forming a complete escape sequence. Prepended
    /// to the next read.
    pending: String,
    /// Events decoded but not yet handed to the app. One read can produce
    /// many; `poll` returns one per call and keeps the rest here.
    queue: List(InputEvent),
  )
}

/// What to turn on when the terminal is initialised.
pub type Options {
  Options(
    /// Report mouse buttons, drags and the wheel as input events.
    mouse: Bool,
    /// Deliver pasted text as one `backend.Paste` event.
    ///
    /// Off by default: with it on, an app that does not handle `Paste` sees
    /// nothing at all when the user pastes, which is worse than the mangled
    /// key presses it sees today.
    paste: Bool,
  )
}

/// Mouse off, bracketed paste off.
pub fn default_options() -> Options {
  Options(mouse: False, paste: False)
}

/// Gap between terminal-size queries when the window is sitting still.
///
/// `io:columns/0` is a synchronous round-trip to the group leader, which is
/// the same process serving the keyboard reader. Asking once per frame put it
/// in contention with input and dropped keystrokes. Noticing a resize up to
/// 100 ms late costs nothing when nothing is moving.
const size_poll_idle_ms = 100

/// Gap between size queries while a resize is under way.
///
/// At the idle rate a drag-resize redraws ten times a second, which reads as
/// stepping rather than following the mouse. Nobody types while dragging a
/// window edge, so the contention the idle rate exists to avoid is not in play.
const size_poll_active_ms = 16

/// How long after the last size change to keep polling at the active rate.
const resize_settle_ms = 400

// ─────────────────────────────────────────────────────────────────
// Backend construction

pub fn new() -> backend.Backend(ErlangTerminalState) {
  new_with_options(default_options())
}

pub fn new_with_mouse() -> backend.Backend(ErlangTerminalState) {
  new_with_options(Options(..default_options(), mouse: True))
}

/// Backend with an explicit feature set.
///
/// ```gleam
/// erlang.new_with_options(erlang.Options(mouse: True, paste: True))
/// ```
pub fn new_with_options(opts: Options) -> backend.Backend(ErlangTerminalState) {
  backend.Backend(
    init: fn() { init_terminal(opts) },
    render: render_ops,
    poll: poll_input,
    next_size: get_terminal_size,
    cleanup: cleanup_terminal,
  )
}

// ─────────────────────────────────────────────────────────────────
// FFI declarations (native Erlang)

@external(erlang, "etui_tty_state", "init")
fn init_tty_state() -> Nil {
  panic as "etui/backend/erlang requires the Erlang target"
}

@external(erlang, "etui_tty_state", "set_raw")
fn set_raw_state(is_raw: Bool) -> Nil {
  let _ = is_raw
  panic as "etui/backend/erlang requires the Erlang target"
}

@external(erlang, "etui_terminal_ffi", "enter_raw")
fn enter_raw_ffi() -> Nil {
  panic as "etui/backend/erlang requires the Erlang target"
}

@external(erlang, "etui_terminal_ffi", "exit_raw")
fn exit_raw_ffi() -> Nil {
  panic as "etui/backend/erlang requires the Erlang target"
}

@external(erlang, "etui_terminal_ffi", "window_size")
fn window_size_ffi() -> Result(#(Int, Int), String) {
  panic as "etui/backend/erlang requires the Erlang target"
}

@external(erlang, "etui_terminal_ffi", "monotonic_ms")
fn monotonic_ms_ffi() -> Int {
  panic as "etui/backend/erlang requires the Erlang target"
}

@external(erlang, "io", "put_chars")
fn write_string(s: String) -> Nil {
  let _ = s
  panic as "etui/backend/erlang requires the Erlang target"
}

@external(erlang, "etui_terminal_ffi", "read_with_timeout")
fn read_with_timeout_ffi(timeout_ms: Int) -> Result(String, Nil) {
  let _ = timeout_ms
  panic as "etui/backend/erlang requires the Erlang target"
}

@external(erlang, "etui_terminal_ffi", "install_sigint_cleanup")
fn install_sigint_cleanup_ffi(cleanup: fn() -> Nil) -> Nil {
  let _ = cleanup
  panic as "etui/backend/erlang requires the Erlang target"
}

@external(erlang, "etui_terminal_ffi", "uninstall_sigint_cleanup")
fn uninstall_sigint_cleanup_ffi() -> Nil {
  panic as "etui/backend/erlang requires the Erlang target"
}

@external(erlang, "etui_terminal_ffi", "write_cleanup")
fn write_cleanup_ffi() -> Nil {
  panic as "etui/backend/erlang requires the Erlang target"
}

// ─────────────────────────────────────────────────────────────────
// Implementation

// DECAWM off. With auto-wrap on, writing the bottom-right cell wraps the
// cursor and scrolls the screen, so the last column had to be left unused.
// Turning it off reclaims that column; `write_cleanup` turns it back on.
const disable_autowrap = "\u{001B}[?7l"

fn init_terminal(opts: Options) -> Result(ErlangTerminalState, Error) {
  init_tty_state()
  let init_ops =
    [EnterAltScreen, Write(disable_autowrap), ClearScreen]
    |> append_if(opts.mouse, EnableMouse)
    |> append_if(opts.paste, EnableBracketedPaste)
  case write_ops_to_stdout(init_ops) {
    Ok(Nil) -> {
      enter_raw_ffi()
      set_raw_state(True)
      let #(cols, rows) = case window_size_ffi() {
        Ok(#(c, r)) -> #(c, r)
        Error(_) -> #(80, 24)
      }
      install_sigint_cleanup_ffi(fn() { terminal_cleanup() })
      Ok(ErlangTerminalState(
        raw_mode_active: True,
        cols: cols,
        rows: rows,
        mouse: opts.mouse,
        last_size_check: monotonic_ms_ffi(),
        // Treat init as a size change: the first moments of an app are
        // exactly when a terminal may still be settling its geometry.
        last_size_change: monotonic_ms_ffi(),
        pending: "",
        queue: [],
      ))
    }
    Error(reason) -> Error(IOError(reason))
  }
}

fn append_if(ops: List(RenderOp), cond: Bool, op: RenderOp) -> List(RenderOp) {
  case cond {
    True -> list.append(ops, [op])
    False -> ops
  }
}

fn render_ops(
  state: ErlangTerminalState,
  ops: List(RenderOp),
) -> Result(ErlangTerminalState, Error) {
  case write_ops_to_stdout(ops) {
    Ok(Nil) -> Ok(state)
    Error(reason) -> Error(IOError(reason))
  }
}

/// Return the next input event.
///
/// One read can carry several key presses (typing faster than the frame rate,
/// or a paste), and it can also stop in the middle of an escape sequence. The
/// backend therefore decodes a read into a queue of events and hands them out
/// one per call, keeping any trailing partial sequence in `pending` for the
/// next read. Previously a whole read became a single `KeyPress`, so only the
/// first key of a burst survived.
fn poll_input(
  state: ErlangTerminalState,
  timeout_ms: Int,
) -> Result(#(InputEvent, ErlangTerminalState), Error) {
  case state.queue {
    [event, ..rest] -> Ok(#(event, ErlangTerminalState(..state, queue: rest)))
    [] -> {
      let #(input_events, pending) = read_events(state, timeout_ms)
      let #(sized, resize_events) = check_resize(state)
      // Resize first: the app should lay out at the new size before it
      // processes keys that were typed during the resize. Both are delivered,
      // which is the point, the old code returned Resize *instead of* the key.
      let next = ErlangTerminalState(..sized, pending: pending, queue: [])
      case list.append(resize_events, input_events) {
        [] -> Ok(#(backend.Tick, next))
        [event, ..rest] ->
          Ok(#(event, ErlangTerminalState(..next, queue: rest)))
      }
    }
  }
}

fn read_events(
  state: ErlangTerminalState,
  timeout_ms: Int,
) -> #(List(InputEvent), String) {
  case read_with_timeout_ffi(timeout_ms) {
    Ok(chunk) -> {
      let input.Parsed(events, pending) = input.parse(state.pending <> chunk)
      #(events, pending)
    }
    // The read timed out, so nothing more is coming: a pending remainder is a
    // real Escape press rather than the start of a sequence.
    Error(_) -> #(input.flush(state.pending), "")
  }
}

fn check_resize(
  state: ErlangTerminalState,
) -> #(ErlangTerminalState, List(InputEvent)) {
  let now = monotonic_ms_ffi()
  case now - state.last_size_check < poll_interval(state, now) {
    True -> #(state, [])
    False -> {
      let checked = ErlangTerminalState(..state, last_size_check: now)
      case window_size_ffi() {
        Ok(#(c, r)) ->
          case c == state.cols && r == state.rows {
            True -> #(checked, [])
            False -> #(
              ErlangTerminalState(
                ..checked,
                cols: c,
                rows: r,
                last_size_change: now,
              ),
              [backend.Resize(c, r)],
            )
          }
        Error(_) -> #(checked, [])
      }
    }
  }
}

// A resize arrives as a burst of small changes while the edge is dragged. The
// first one switches to the active rate; the rate falls back once the window
// has been still for resize_settle_ms.
fn poll_interval(state: ErlangTerminalState, now: Int) -> Int {
  case now - state.last_size_change < resize_settle_ms {
    True -> size_poll_active_ms
    False -> size_poll_idle_ms
  }
}

fn get_terminal_size(
  state: ErlangTerminalState,
) -> Result(#(TerminalSize, ErlangTerminalState), Error) {
  case window_size_ffi() {
    Ok(#(w, h)) -> Ok(#(backend.TerminalSize(width: w, height: h), state))
    Error(_) -> Ok(#(backend.TerminalSize(width: 80, height: 24), state))
  }
}

// Shared cleanup: idempotent, safe to call from both normal exit and SIGINT.
// Order matters: write escape sequences BEFORE exit_raw_ffi so the sequences
// reach the terminal while the I/O group leader is still set up correctly.
fn terminal_cleanup() -> Nil {
  uninstall_sigint_cleanup_ffi()
  write_cleanup_ffi()
  exit_raw_ffi()
  set_raw_state(False)
  Nil
}

fn cleanup_terminal(_state: ErlangTerminalState) -> Nil {
  terminal_cleanup()
}

// ─────────────────────────────────────────────────────────────────
// Helpers

fn write_ops_to_stdout(ops: List(RenderOp)) -> Result(Nil, String) {
  let output =
    ops
    |> list.fold("", fn(acc, op) { acc <> render_op_to_string(op) })

  case output {
    "" -> Ok(Nil)
    s -> {
      write_string(s)
      Ok(Nil)
    }
  }
}

fn render_op_to_string(op: RenderOp) -> String {
  case op {
    MoveCursor(x, y) ->
      "\u{001B}[" <> int.to_string(y + 1) <> ";" <> int.to_string(x + 1) <> "H"
    Write(s) -> s
    ClearScreen -> "\u{001B}[2J\u{001B}[H"
    EnterAltScreen -> "\u{001B}[?1049h"
    ExitAltScreen -> "\u{001B}[?1049l"
    // Button-event tracking (1002) rather than plain click tracking (1000):
    // it reports motion while a button is held, which is what makes MouseDrag
    // possible. 1006 is the SGR encoding, which lifts the 223-column limit.
    EnableMouse -> "\u{001B}[?1002h\u{001B}[?1006h"
    // Clear all common xterm mouse/alt-scroll modes so the shell does not
    // inherit wheel/click reporting after the app exits.
    DisableMouse ->
      "\u{001B}[?1007l\u{001B}[?1015l\u{001B}[?1006l\u{001B}[?1005l\u{001B}[?1003l\u{001B}[?1002l\u{001B}[?1000l"
    EnableBracketedPaste -> "\u{001B}[?2004h"
    DisableBracketedPaste -> "\u{001B}[?2004l"
  }
}
