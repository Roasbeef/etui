# Changelog

All notable changes to étui are listed here.

## 2.0.0 - unreleased

Ratatui-level flexibility. Layout and composition primitives, a real input
parser, and a Terminal you can drive from your own loop.

### Breaking

Small, but they will not compile silently:

- **`backend.InputEvent` gained `MouseDrag`, `MouseMove` and `Paste`**, and
  **`backend.RenderOp` gained `EnableBracketedPaste` and
  `DisableBracketedPaste`**. A `case` over either that was exhaustive without a
  `_ ->` arm now fails to compile. Adding the arm is the whole fix.
- **`keys.match` answers `Unknown` rather than `Char` for a multi-grapheme
  string.** With modified keys now reaching the app, `"shift+left"` would have
  arrived at a text field as a ten-grapheme "character" to insert. Single
  graphemes are still `Char`, so ordinary typing is unaffected.

### Added

- **`etui/input`:** incremental terminal input parsing, pure and testable
  without a TTY. `parse` returns every event it can decode plus the bytes that
  do not yet form a complete sequence; `flush` resolves a leftover into Escape
  once a read times out.
- **Modified keys:** ctrl, alt and shift on arrows, navigation and function
  keys, named in a fixed order (`"ctrl+shift+left"`). These previously reached
  the app as raw escape text.
- **`backend.Paste`:** pasted text as one event. Opt in with
  `erlang.new_with_options(erlang.Options(mouse: False, paste: True))`. It is
  off by default because an app that ignores `Paste` would see nothing at all
  when the user pastes.
- **`backend.MouseDrag` and `backend.MouseMove`,** with mouse tracking raised
  from click reporting (1000) to button-event reporting (1002) so drags are
  actually reported.
- **`erlang.new_with_options` and `erlang.Options`.** `new` and
  `new_with_mouse` are unchanged.

- **`buffer.blit/4`:** copy a window of one buffer into another, clipped
  against both. Composite an off-screen canvas or a cached panel into the frame
  without walking cells from the caller.
- **`buffer.set_style/3`:** repaint a rect without touching cell content.
- **`geometry.Margin`, `inner/2`, `offset/3`, `clamp/2`, `size/1`, `rows/1`,
  `columns/1`:** the rect helpers ratatui exposes on `Rect`. `inner/2` follows
  ratatui's saturation rule.
- **`text.normalise_newlines/1` and `text.expand_tabs/2`:** exposed so callers
  that do their own wrapping can apply the same normalisation, and so tab width
  can be chosen per call site.

### Fixed

- **Keys were dropped when typing fast or pasting:** the backend turned an
  entire read into one `KeyPress`, so everything after the first key in a
  buffered read was lost, and a sequence split across two reads was mangled.
  Reads are now decoded into a queue and delivered one event at a time.
- **A resize ate the keystroke that arrived with it:** the poll returned
  `Resize` *instead of* the input event. Both are queued now.
- **Dragging the mouse looked like a stream of clicks:** the SGR decoder
  ignored the motion bit. Scrolling with a modifier held (button code 68 and
  up) was also reported as a button press.
- **`\r` corrupted every position after it:** `text.wrap` split on `\n` only,
  leaving a bare `\r` in the output. It measures zero cells, so the rest of the
  line drew one column to the left. `\r\n` and lone `\r` are now normalised.
- **Tabs were silently deleted:** a tab measured 0 cells and the fill FFI drops
  control characters, so `"a\tb"` reached the buffer as `"ab"`. `text.wrap` now
  expands tabs to 8-column tab stops.
- **Non-ASCII text vanished from `buffer_new_filled` on Erlang:** the native
  `fill_all_rows` path consumed non-ASCII bytes without emitting a cell, so a
  filled row lost every CJK and emoji character. The JavaScript fallback was
  correct, which is how the two targets came to disagree.
- **Wide graphemes broke at clip boundaries:** a window that started on the
  right half of a wide grapheme, or ended on its left half, copied an orphan.
  An orphan continuation renders as nothing and shifts the row left; an orphan
  wide cell draws over its neighbour. `buffer.blit` and both fill paths now
  blank the half that cannot be drawn whole.
- **The last terminal column was unusable:** auto-wrap made writing the
  bottom-right cell scroll the screen, so the backend reserved a column.
  DECAWM is now disabled for the session and restored on exit.
- **Terminal size was queried once per frame:** `io:columns/0` is a synchronous
  round-trip to the group leader that also serves the keyboard reader, putting
  the two in contention. Queries are throttled to 100 ms.

### Changed

- **`text.wrap` and `buffer.clear` are O(n):** both had quadratic accumulation
  (list appends, string copies) in their inner loops.
- **CI runs the suite on JavaScript as well as Erlang.** Only a smoke app ran
  there before, which is why the two targets could diverge unnoticed.

## 1.0.1 - 2026-06-06

### Fixed

- **Keyboard I/O dropped keys (#2, #4):** replaced spawn/kill polling loop in
  `etui_terminal_ffi.erl` with persistent `etui_kbd_reader` actor. Reader
  blocks on `io:get_chars` and forwards `{etui_input, Bin}` to owner.
  Eliminates dropped keys and TTY lock contention in 60FPS loops.
  Thanks [@salespaulo](https://github.com/salespaulo).
- **Input widget horizontal scroll (#3, #5):** removed hardcoded `- 2`
  column margin in `widgets/input` truncation and cursor tracking. Uses
  full `area.size.width` via `int.max(1, area.size.width)`. Cursor no
  longer jumps prematurely; widget fills assigned cells.
  Thanks [@salespaulo](https://github.com/salespaulo).

## 1.0.0 - 2026-05-27

First public release.

### Added

- Buffer-diff rendering with cell-accurate Unicode (UAX #29 grapheme clusters).
- Layout primitives: `Length`, `Min`, `Max`, `Percentage`, `Ratio`, `Fill`,
  plus `split_with_spacing`, `split_flex`, `split_responsive`.
- 32 widgets: block, paragraph, list, table, tabs, gauge, line_gauge, hbar,
  chart, sparkline, canvas, input, textarea, tree, scrollbar, popup, statusbar,
  spinner, marquee, dialog, form, notification, scene, progress, gradient_bar,
  line, clear, scroll_view, paginator, help, fieldset, multi_select.
- Bubbletea-inspired additions (port of ratatui-cheese ideas):
  - Spinner gains 10 presets (MiniDot, Jump, Pulse, Points, Globe, Moon,
    Monkey, Meter, Hamburger, Ellipsis) on top of Dots, Line, Circle, Bounce.
  - Tree supports a right-aligned count per node via `leaf_with_count`,
    `node_with_count` and `with_count`.
  - Input gains `with_prompt`, `with_password`, `with_mask` for prompt
    prefixes and masked password fields.
  - Paginator: dot or arabic page indicator, with `slice/2` helper.
  - Help: short single-line and full multi-column key bindings view.
  - Fieldset: horizontal rule with inline title (left/center/right).
  - MultiSelect: toggle list with optional `max` cap and cursor scrolling.
- 10 built-in themes: dracula, nord, catppuccin_mocha, catppuccin_latte,
  monokai, solarized_dark, gruvbox_dark, tokyo_night, dark, light.
- App loops with crash-restore on Erlang `try/after`: `run`, `run_buffered`,
  `run_animated`, `run_buffered_cursor`.
- Backends for Erlang/BEAM, Node.js and the browser. `etui/backend/default`
  picks one at compile time.
- Typed keyboard input via `keys.match`, command tables via `keymap`,
  multi-slot focus via `focus`, integer-math easing via `anim`.
- Composition helpers in `etui/widget`: `layer`, `at`, `compose`, `stack`,
  `StatefulWidget`, `AnimatedWidget`.
- Test mock backend for app-loop coverage (`test/app_loop_test`).
