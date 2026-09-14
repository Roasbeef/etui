// Apply optimized ANSI to a terminal emulator, comparing with a full repaint.
// Build first: gleam test --target javascript
// Install the optional oracle outside the repo:
//   npm install --prefix /tmp/etui-oracle @xterm/headless
// Run: node dev/scroll_screen_test.mjs /tmp/etui-oracle/node_modules/@xterm/headless
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import * as buffer from '../build/dev/javascript/etui/etui/buffer.mjs';
import * as style from '../build/dev/javascript/etui/etui/style.mjs';
import { Position } from '../build/dev/javascript/etui/etui/geometry.mjs';
import { fixture } from '../build/dev/javascript/etui/scroll_diff_test.mjs';
const require = createRequire(import.meta.url);
const { Terminal } = require(process.argv[2] || '@xterm/headless');
const write = (term, text) => new Promise(resolve => term.write(text, resolve));

function decorated(offset, sidebar, mode) {
  let frame = fixture(offset, sidebar);
  for (let y = 2; y < 22; y++) {
    const n = y + offset;
    if (mode === 1) {
      frame = buffer.set_string_linked(frame, new Position(8, y),
        `${n} 界面 語 e\u0301`,
        style.with_bg(style.with_fg(style.default_style(), new style.Indexed(n % 16)), new style.Indexed(20 + n % 8)),
        `https://example.test/row/${n}`);
    } else if (mode === 2 && n % 4 === 0) {
      frame = buffer.set_string(frame, new Position(0, y), ' '.repeat(60),
        style.with_bg(style.default_style(), new style.Indexed(20 + n % 8)));
    }
  }
  return frame;
}

function snapshot(term) {
  const rows = [];
  for (let y = 0; y < 24; y++) {
    const row = [];
    for (let x = 0; x < 80; x++) {
      const c = term.buffer.active.getLine(y).getCell(x);
      row.push([c.getChars() || ' ', c.getWidth(), c.getFgColorMode(), c.getFgColor(),
        c.getBgColorMode(), c.getBgColor(), c.isBold(), c.isItalic(), c.isUnderline(), c.isInverse(), term._core._oscLinkService.getLinkData(c.extended.urlId)?.uri || '']);
    }
    rows.push(row);
  }
  return rows;
}

let tested = 0, scrolled = 0;
for (const sidebar of [0, 60]) {
  for (const mode of [0, 1, 2]) {
    for (let distance = -8; distance <= 8; distance++) {
      const before = decorated(12, sidebar, mode);
      let after = decorated(12 + distance, sidebar, mode);
      // A concurrent edit inside the shifted region must also be repaired.
      if (distance % 3 === 0) after = buffer.set_string(after, new Position(30, 12), 'edited!', style.default_style());
      const ansi = buffer.diff_fullscreen_to_ansi(before, after);
      const plain = buffer.diff_to_ansi(before, after);
      assert.ok(Buffer.byteLength(ansi) <= Buffer.byteLength(plain));
      const got = new Terminal({ cols: 80, rows: 24, allowProposedApi: true });
      const want = new Terminal({ cols: 80, rows: 24, allowProposedApi: true });
      await write(got, '\x1b[?1049h' + buffer.to_ansi(before));
      await write(got, ansi);
      await write(want, '\x1b[?1049h' + buffer.to_ansi(after));
      const actual = snapshot(got), expected = snapshot(want);
      for (let y = 0; y < 24; y++) for (let x = 0; x < 80; x++) {
        assert.deepEqual(actual[y][x], expected[y][x], `sidebar=${sidebar} mode=${mode} distance=${distance} cell=${x},${y}`);
      }
      // The next full-screen newline must use restored margins, not the old
      // transcript region; compare the next operation as well as this frame.
      await write(got, '\x1b[24;1H\n');
      await write(want, '\x1b[24;1H\n');
      assert.deepEqual(snapshot(got), snapshot(want), 'scroll margins restored');
      if (/\x1b\[\d+[ST]/.test(ansi)) scrolled++;
      got.dispose(); want.dispose(); tested++;
    }
  }
}
assert.ok(scrolled > 40, 'the oracle must exercise scroll commands, not only fallbacks');
console.log(`${tested} screen transitions matched full repaint; ${scrolled} used scroll commands`);
