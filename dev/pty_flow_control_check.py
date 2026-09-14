#!/usr/bin/env python3
"""Check Ctrl+S delivery, output progress, and restored modes on a real PTY.

Run after `gleam build`: python3 dev/pty_flow_control_check.py.
The slave starts with XON/XOFF enabled, as an ordinary shell terminal does.
No Ctrl+Q is sent: it would hide a swallowed Ctrl+S by resuming output.
"""

import fcntl
import os
import pty
import select
import signal
import struct
import subprocess
import termios
import time
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent


def run(ending):
    master, slave = pty.openpty()
    os.set_blocking(master, False)
    modes = termios.tcgetattr(slave)
    modes[0] |= termios.IXON
    modes[3] |= termios.ICANON | termios.ECHO
    modes[6][termios.VSTOP] = b"\x13"
    modes[6][termios.VSTART] = b"\x11"
    termios.tcsetattr(slave, termios.TCSANOW, modes)
    fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", 24, 80, 0, 0))

    def own_terminal():
        os.setsid()
        fcntl.ioctl(0, termios.TIOCSCTTY, 0)

    # This probe creates a terminal emulator's PTY directly. Declare the
    # emulator type rather than inheriting an unset CI TERM, which makes OTP
    # decline its interactive raw-mode setup before etui can read input.
    app = subprocess.Popen(
        ["gleam", "run", "-m", "etui_flow_control_probe"],
        cwd=REPO, stdin=slave, stdout=slave, stderr=slave,
        preexec_fn=own_terminal,
        env={**os.environ, "ERL_FLAGS": "+B", "TERM": "xterm-256color"},
    )
    output = bytearray()

    def wait_for(predicate, label, timeout=15):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            if predicate():
                return
            if select.select([master], [], [], 0.05)[0]:
                try:
                    output.extend(os.read(master, 65536))
                except BlockingIOError:
                    pass
        raise AssertionError(f"{ending}: timed out waiting for {label}: {output!r}")

    def restored():
        current = termios.tcgetattr(master)
        return (
            current[0] & termios.IXON
            and current[3] & termios.ICANON
            and current[3] & termios.ECHO
            and b"\x1b[?1049l" in output
        )

    try:
        wait_for(lambda: b"FLOW_READY" in output, "first frame")
        raw = termios.tcgetattr(master)
        assert not raw[0] & termios.IXON
        assert not raw[3] & termios.ICANON
        assert not raw[3] & termios.ECHO
        os.write(master, b"\x13")
        wait_for(lambda: b"CTRL_S_RECEIVED" in output, "Ctrl+S delivery", 3)
        assert not termios.tcgetattr(master)[0] & termios.IXON
        os.write(master, b"x")
        wait_for(lambda: b"OUTPUT_CONTINUES" in output, "continued output", 3)
        if ending == "quit":
            os.write(master, b"q")
        else:
            sig = signal.SIGKILL if ending == "kill" else signal.SIGINT
            os.killpg(app.pid, sig)
        wait_for(lambda: app.poll() is not None and restored(), "terminal restoration")
        if ending == "quit":
            assert app.returncode == 0, f"normal exit returned {app.returncode}"
        print(f"{ending}: Ctrl+S delivered, output continued, terminal restored")
    finally:
        # Keep the terminal allocated until the watchdog has restored it, even
        # on assertion failure, so a later run cannot inherit its cleanup.
        if app.poll() is None:
            os.killpg(app.pid, signal.SIGKILL)
        try:
            # A regression can leave kernel output suspended. Resume it only
            # after the assertions, so teardown can drain and the VM can die.
            termios.tcflow(master, termios.TCOON)
            wait_for(lambda: app.poll() is not None and restored(), "cleanup after probe")
        finally:
            os.close(slave)
            os.close(master)


if __name__ == "__main__":
    for ending in ("quit", "kill", "sigint"):
        run(ending)
