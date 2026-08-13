@target(javascript)
/// Browser (xterm.js) terminal backend for the JavaScript target.
///
/// Provides the same `AsyncBackend` interface as `node.gleam` but uses an
/// xterm.js `Terminal` instance instead of Node's stdin/stdout.
///
/// **Setup:** call `browser_ffi.setup(term)` from JavaScript before calling
/// your app's `main()`. The `priv/components/DinoBrowser.astro` component
/// shows the full wiring.
///
/// Requirements:
/// - Compiled with `gleam build --target javascript`
/// - An xterm.js Terminal attached to the DOM before `main()` runs
///
/// Example (JavaScript side):
/// ```javascript
/// import { Terminal } from "xterm";
/// import { setup } from "./build/dev/javascript/etui/etui/backend/browser_ffi.mjs";
/// import { main } from "./build/dev/javascript/etui/your_app.mjs";
///
/// const term = new Terminal({ cols: 120, rows: 36 });
/// term.open(document.getElementById("terminal"));
/// setup(term);
/// main();
/// ```
import etui/backend.{
  type Error, type InputEvent, type RenderOp, type TerminalSize, ClearScreen,
  DisableBracketedPaste, DisableMouse, EnableBracketedPaste, EnableMouse,
  EnterAltScreen, ExitAltScreen, MoveCursor, Resize, Tick, Write,
}
@target(javascript)
import etui/input

@target(javascript)
import gleam/int

@target(javascript)
import gleam/javascript/promise

@target(javascript)
import gleam/list

// ─────────────────────────────────────────────────────────────────
// Types

@target(javascript)
pub type BrowserState {
  BrowserState(
    cols: Int,
    rows: Int,
    /// Bytes read but not yet forming a complete escape sequence.
    pending: String,
    /// Events decoded but not yet handed to the app.
    queue: List(InputEvent),
  )
}

// ─────────────────────────────────────────────────────────────────
// Backend construction

@target(javascript)
pub fn new() -> backend.AsyncBackend(BrowserState) {
  backend.AsyncBackend(
    init: init_terminal,
    render: render_ops,
    poll: poll_input,
    next_size: get_terminal_size,
    cleanup: cleanup_terminal,
  )
}

// ─────────────────────────────────────────────────────────────────
// FFI declarations (xterm.js via browser_ffi.mjs)

@target(javascript)
@external(javascript, "./browser_ffi.mjs", "enterRaw")
fn enter_raw_ffi() -> Nil {
  panic as "etui/backend/browser requires the JavaScript target"
}

@target(javascript)
@external(javascript, "./browser_ffi.mjs", "exitRaw")
fn exit_raw_ffi() -> Nil {
  panic as "etui/backend/browser requires the JavaScript target"
}

@target(javascript)
@external(javascript, "./browser_ffi.mjs", "writeStdout")
fn write_stdout_ffi(s: String) -> Nil {
  let _ = s
  panic as "etui/backend/browser requires the JavaScript target"
}

@target(javascript)
@external(javascript, "./browser_ffi.mjs", "windowSize")
fn window_size_ffi() -> Result(#(Int, Int), String) {
  panic as "etui/backend/browser requires the JavaScript target"
}

@target(javascript)
@external(javascript, "./browser_ffi.mjs", "readChunk")
fn read_chunk_ffi(timeout_ms: Int) -> promise.Promise(String) {
  let _ = timeout_ms
  panic as "etui/backend/browser requires the JavaScript target"
}

@target(javascript)
@external(javascript, "./browser_ffi.mjs", "takeResize")
fn take_resize_ffi() -> List(Int) {
  panic as "requires the JavaScript target"
}

@target(javascript)
@external(javascript, "./browser_ffi.mjs", "registerCleanup")
fn register_cleanup_ffi(cleanup: fn() -> Nil) -> Nil {
  let _ = cleanup
  panic as "etui/backend/browser requires the JavaScript target"
}

// ─────────────────────────────────────────────────────────────────
// ANSI sequences (identical to node/erlang backends)

@target(javascript)
fn render_op_to_ansi(op: RenderOp) -> String {
  case op {
    Write(s) -> s
    MoveCursor(x, y) ->
      "\u{001B}[" <> int.to_string(y + 1) <> ";" <> int.to_string(x + 1) <> "H"
    ClearScreen -> "\u{001B}[2J\u{001B}[H"
    EnterAltScreen -> "\u{001B}[?1049h"
    ExitAltScreen -> "\u{001B}[?1049l"
    EnableMouse -> "\u{001B}[?1000h\u{001B}[?1002h\u{001B}[?1006h"
    DisableMouse ->
      "\u{001B}[?1007l\u{001B}[?1015l\u{001B}[?1006l\u{001B}[?1005l\u{001B}[?1003l\u{001B}[?1002l\u{001B}[?1000l"
    EnableBracketedPaste -> "\u{001B}[?2004h"
    DisableBracketedPaste -> "\u{001B}[?2004l"
  }
}

// ─────────────────────────────────────────────────────────────────
// Implementation

@target(javascript)
fn init_terminal() -> Result(BrowserState, Error) {
  enter_raw_ffi()
  let ops = [EnterAltScreen, ClearScreen, EnableMouse]
  let ansi = list.map(ops, render_op_to_ansi) |> string_join("")
  write_stdout_ffi(ansi)
  let #(cols, rows) = case window_size_ffi() {
    Ok(#(c, r)) -> #(c, r)
    Error(_) -> #(80, 24)
  }
  let state = BrowserState(cols: cols, rows: rows, pending: "", queue: [])
  register_cleanup_ffi(fn() {
    let _ = cleanup_terminal(state)
    Nil
  })
  Ok(state)
}

@target(javascript)
fn render_ops(
  state: BrowserState,
  ops: List(RenderOp),
) -> Result(BrowserState, Error) {
  let ansi = list.map(ops, render_op_to_ansi) |> string_join("")
  write_stdout_ffi(ansi)
  Ok(state)
}

@target(javascript)
/// Return the next input event.
///
/// One read can carry several key presses, or stop in the middle of an escape
/// sequence. The chunk is decoded by `etui/input`, the same parser the Erlang
/// backend uses, into a queue that is handed out one event per call. The
/// parsing used to live in JavaScript in the FFI, which is why this target
/// spent a release without modified keys, bracketed paste or mouse drags.
fn poll_input(
  state: BrowserState,
  timeout_ms: Int,
) -> promise.Promise(Result(#(InputEvent, BrowserState), Error)) {
  case state.queue {
    [event, ..rest] ->
      promise.resolve(Ok(#(event, BrowserState(..state, queue: rest))))
    [] ->
      promise.map(read_chunk_ffi(timeout_ms), fn(chunk) {
        let #(events, pending) = case chunk {
          // Nothing arrived before the timeout, so a half-finished sequence is
          // a real Escape press rather than the start of something.
          "" -> #(input.flush(state.pending), "")
          _ -> {
            let input.Parsed(decoded, rest) =
              input.parse(state.pending <> chunk)
            #(decoded, rest)
          }
        }
        let #(sized, resize) = case take_resize_ffi() {
          [cols, rows] -> #(BrowserState(..state, cols: cols, rows: rows), [
            Resize(cols, rows),
          ])
          _ -> #(state, [])
        }
        let next = BrowserState(..sized, pending: pending, queue: [])
        case list.append(resize, events) {
          [] -> Ok(#(Tick, next))
          [event, ..rest] -> Ok(#(event, BrowserState(..next, queue: rest)))
        }
      })
  }
}

@target(javascript)
fn get_terminal_size(
  state: BrowserState,
) -> Result(#(TerminalSize, BrowserState), Error) {
  let #(cols, rows) = case window_size_ffi() {
    Ok(#(c, r)) -> #(c, r)
    Error(_) -> #(state.cols, state.rows)
  }
  Ok(#(
    backend.TerminalSize(width: cols, height: rows),
    BrowserState(cols: cols, rows: rows, pending: "", queue: []),
  ))
}

@target(javascript)
fn cleanup_terminal(state: BrowserState) -> Nil {
  let ops = [DisableMouse, ExitAltScreen]
  let ansi = list.map(ops, render_op_to_ansi) |> string_join("")
  write_stdout_ffi(ansi)
  exit_raw_ffi()
  let _ = state
  Nil
}

// ─── String join helper ──────────────────────────────────────────

@target(javascript)
fn string_join(parts: List(String), sep: String) -> String {
  case parts {
    [] -> ""
    [h] -> h
    [h, ..rest] -> h <> sep <> string_join(rest, sep)
  }
}
