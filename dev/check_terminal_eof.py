#!/usr/bin/env python3
"""Exercise the private cleanup drain against a bounded closed-input fixture."""

from pathlib import Path
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[1]
# Export private functions in a temporary test build only. Testing the drain
# directly avoids changing the test runner's real terminal mode during cleanup.
with tempfile.TemporaryDirectory(prefix="etui-eof-") as build:
    subprocess.run(
        ["erlc", "+export_all", "-o", build,
         str(ROOT / "src/etui_terminal_ffi.erl")],
        check=True, capture_output=True, timeout=20,
    )
    for reply in ("eof", "{error,terminated}"):
        expression = '''
          Owner = self(),
          Console = spawn(fun Loop() ->
            receive
              {io_request, From, Ref, _} ->
                Owner ! read,
                From ! {io_reply, Ref, REPLY},
                receive
                  {io_request, _, _, _} -> Owner ! repeated_read
                end
            end
          end),
          true = group_leader(Console, self()),
          ok = etui_terminal_ffi:drain_input(20),
          receive read -> ok after 1000 -> halt(2) end,
          receive repeated_read -> halt(3) after 50 -> halt(0) end.
        '''.replace("REPLY", reply)
        # Only the first read receives a reply. Even the unfixed drain can do
        # at most one extra read, then reaches its normal timeout and exits.
        subprocess.run(
            ["erl", "+S", "2:2", "-noshell", "-pa", build, "-eval", expression],
            check=True, capture_output=True, timeout=10,
        )
print("terminal cleanup stops after one EOF/error read")
