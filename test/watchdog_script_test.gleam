@target(erlang)
/// The shell fallback, read rather than run.
///
/// When the runtime dies without unwinding — a `halt`, a break handler, a
/// signal the VM does not get to handle — no Gleam code runs and the terminal
/// stays in raw mode with the alternate screen up. An orphan shell process
/// watches for that and hands the terminal back itself.
///
/// It used to be a bash script using `$'\x1b'`, which is a bash extension. On
/// a system whose /bin holds no bash — Alpine, NixOS, a BSD — the port never
/// opened and the fallback silently did not exist, which is the worst state
/// for a safety net to be in. These pin it to POSIX.
import etui/backend
import gleam/string
import gleeunit/should

@target(erlang)
@external(erlang, "etui_terminal_ffi", "watchdog_script")
fn watchdog_script(seq: String, pid: String, tty: String) -> String

@target(erlang)
fn script() -> String {
  watchdog_script(backend.restore_sequence(), "4242", "/dev/ttys004")
}

@target(erlang)
pub fn the_script_uses_no_bash_extensions_test() {
  let s = script()
  // ANSI-C quoting, the reason this needed bash at all.
  string.contains(s, "$'") |> should.equal(False)
  // Other habits that are not POSIX.
  string.contains(s, "[[") |> should.equal(False)
  string.contains(s, "read -t") |> should.equal(False)
  string.contains(s, "/bin/bash") |> should.equal(False)
}

@target(erlang)
pub fn the_escape_bytes_are_octal_escaped_test() {
  // ESC is \033, and every other byte is spelled the same way, so no shell
  // has to be trusted with a quoting rule. `[?25h` is 133 077 062 065 150.
  string.contains(script(), "\\033\\133\\077\\062\\065\\150")
  |> should.equal(True)
}

@target(erlang)
pub fn the_script_waits_then_restores_then_sanes_the_tty_test() {
  let s = script()
  string.contains(s, "kill -0") |> should.equal(True)
  string.contains(s, "printf") |> should.equal(True)
  // stty against the terminal, not against whatever stdin happens to be:
  // `stty sane` with os:cmd's /dev/null stdin reset /dev/null and nothing else.
  string.contains(s, "stty sane < '/dev/ttys004'") |> should.equal(True)
}

@target(erlang)
pub fn a_normal_exit_leaves_the_script_nothing_to_do_test() {
  // The flag file the app writes on its way out. Without this check the
  // watchdog would repaint the terminal after every clean quit.
  string.contains(script(), "[ -f") |> should.equal(True)
  string.contains(script(), "exit 0") |> should.equal(True)
}

@target(erlang)
pub fn the_watcher_is_an_orphan_test() {
  // Backgrounded from a shell that exits immediately, so the process the VM
  // can signal is not the process doing the watching.
  string.ends_with(script(), ") &") |> should.equal(True)
}
