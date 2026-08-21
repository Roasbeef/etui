#!/usr/bin/env python3
"""Does the terminal come back?

Every way an etui app can end has to leave the terminal usable, and none of
it can be checked from the test suite: it needs a real terminal device, and
the interesting paths are the ones where no Gleam code gets to run.

    python3 dev/pty_cleanup_check.py

Allocates a pty, gives the app a controlling terminal on it (a plain pipe is
not enough: without one, ps(1) cannot name the terminal and the library
correctly declines to install its watchdog), runs the lab on it, ends it
three different ways, and reads back what arrived on the terminal.

  quit      the app quits through its own loop
  kill      the runtime is killed outright, so no cleanup code runs and the
            orphan shell watchdog is the only thing left
  sigint    an external SIGINT. Needs the break handler disabled — +B, or
            equivalently +Bd — without which the VM takes the signal for its
            own break handler and neither exits nor reads input again. That is
            a property of the VM, not of etui.
"""

import os, pty, select, signal, subprocess, sys, time, fcntl, termios

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RESTORE = {
    "mouse off": b"\x1b[?1000l",
    "paste off": b"\x1b[?2004l",
    "left alt screen": b"\x1b[?1049l",
    "autowrap on": b"\x1b[?7h",
    "attributes reset": b"\x1b[0m",
    "cursor shown": b"\x1b[?25h",
}


def run(ending, env=None, label=None):
    master, slave = pty.openpty()
    os.set_blocking(master, False)

    def own_terminal():
        os.setsid()
        fcntl.ioctl(0, termios.TIOCSCTTY, 0)

    app = subprocess.Popen(
        ["gleam", "run", "-m", "etui_lab"], cwd=REPO,
        stdin=slave, stdout=slave, stderr=slave,
        preexec_fn=own_terminal, env={**os.environ, **(env or {})},
    )
    # The slave fd stays open here on purpose. When the app dies the kernel
    # would otherwise release the pty, and a later run can be handed the same
    # device: the watchdog of one run then writes into the terminal of the
    # next, which looks exactly like a failure that moved.
    out = bytearray()

    def pump(seconds):
        end = time.time() + seconds
        while time.time() < end:
            if select.select([master], [], [], 0.1)[0]:
                try:
                    out.extend(os.read(master, 65536))
                except OSError:
                    return

    pump(15)                      # compile, then draw the first frame
    mark = len(out)

    if ending == "quit":
        os.write(master, b"q")
    elif ending == "kill":
        os.killpg(os.getpgid(app.pid), signal.SIGKILL)
    elif ending == "sigint":
        os.killpg(os.getpgid(app.pid), signal.SIGINT)
    pump(8)

    try:
        app.wait(timeout=5)
    except subprocess.TimeoutExpired:
        os.killpg(os.getpgid(app.pid), signal.SIGKILL)
        pump(3)
    pump(1)

    os.close(slave)
    os.close(master)
    tail = bytes(out[mark:])
    missing = [name for name, seq in RESTORE.items() if seq not in tail]
    name = label or ending
    print(f"  {name:16} {'ok' if not missing else 'MISSING ' + ', '.join(missing)}")
    return not missing


if __name__ == "__main__":
    print("terminal restored after:")
    ok = run("quit")
    time.sleep(1)
    ok &= run("kill")
    time.sleep(1)
    ok &= run("sigint", env={"ERL_FLAGS": "+B"}, label="sigint +B")
    time.sleep(1)
    ok &= run("sigint", env={"ERL_AFLAGS": "+Bd"}, label="sigint +Bd")
    sys.exit(0 if ok else 1)
