# Inline images

etui can draw an image inside a box of cells on terminals that implement the
kitty graphics protocol (kitty, Ghostty) or iTerm2's inline images (OSC 1337).
It never decodes pixels: the terminal does that, and on any other terminal the
app draws its own text in the box instead. There is no braille or half-block
fallback.

A runnable version of everything below is `examples/image`:

```sh
cd examples/image
gleam run -- path/to/file.png
```

## Asking the terminal

A terminal cannot be identified from its environment. `TERM_PROGRAM` survives
`ssh`, and a multiplexer in between may not pass graphics through. So an app
asks once, at launch, before the alternate screen, and believes only a
positive answer.

```gleam
import etui/graphics
import etui/graphics/probe

let caps = case graphics.decide(getenv) {
  graphics.Probe -> probe.run(200)
  graphics.Skip(_) -> graphics.none()
}
```

`graphics.decide` takes the app's own environment lookup and skips the probe
inside Herdr (`HERDR_ENV`) and under `NO_COLOR`. tmux is asked like any other
terminal: it answers the version and device-attribute requests itself and
drops the graphics query, so the answer comes back "no" without a special
case.

`probe.run(timeout_ms)` (Erlang) enters raw mode, writes `probe.query()`, and
reads until the terminal answers the primary device attributes request (DA1)
or the deadline passes. The query is, in order:

| Query | Positive answer |
|---|---|
| kitty `a=q` for one pixel, id 31 | `ESC _ G i=31;OK ESC \` |
| XTVERSION, `CSI > 0 q` | a name starting `iTerm2` |
| `CSI 16 t` | the cell size in pixels |
| `CSI 14 t` and `CSI 18 t` | the window in pixels and in cells, for terminals without `16 t` |
| DA1, `CSI c` | always answered; ends the probe |

Terminals answer in the order they were asked, so a reply that has not come
before DA1's is not coming. A local terminal answers in a few milliseconds;
the deadline is spent in full only on a terminal that does not answer DA1.

`probe.run` leaves the terminal in raw mode for the backend that follows,
because the Erlang runtime switches into raw mode once per session. Run it in
the process that will run the app loop, then open the backend.

The parsing is pure and can be driven by hand: `probe.new()`, `probe.feed`
for each chunk read, `probe.status` to see whether DA1 has arrived, and
`probe.capabilities` for the answer at any point. Keys typed while the probe
runs are kept apart (`probe.typed`), and a reply split across reads is
completed by the next one.

A reply that arrives after the deadline reaches the backend instead. The
input parser recognises the same six replies (`etui/graphics/reply`) and
drops them, so a slow terminal's answer never reaches the app as keys.

## Choosing a size

`graphics.fit(width, height, cell_size, max)` gives the cell box that shows an
image whole: its natural size when that fits, scaled down otherwise, with the
aspect ratio kept. It never scales up. The image's pixel size comes from the
file's header, which the app reads; etui does not. Use the probed
`caps.cell_size`, or a guess such as 8x16 when the terminal did not say.

## kitty and Ghostty: placeholder cells

The image is transmitted once and shown by text. Each cell of the box holds
U+10EEEE with three combining marks, its row, its column and the high byte of
the image id, in a foreground colour that holds the id's low 24 bits.

```gleam
import etui/graphics/kitty

let assert Ok(id) = kitty.image_id(4_242_424)

// After the backend has opened, outside a frame:
io.print(kitty.transmit(id, png) <> kitty.place(id, box))

// In each frame that shows it, last:
buf |> kitty.render(position, id, box)

// When it is gone for good:
io.print(kitty.delete(id))
```

To the frame differ these are ordinary one-column cells. Only the cells that
change are written, a scrolled region carries them, a box clipped by the top
of the buffer (a negative `position.y`) shows the rows that remain, and the
image disappears with the text around it. Every cell carries all three of its
marks, so a patch that starts in the middle of a box is still read correctly.
`kitty.render` writes through `buffer.set_cells`, which blanks the other half
of a wide character the box's edge cuts.

- **Transmit after the alternate screen is entered.** kitty and Ghostty keep
  each screen's images apart.
- **Write commands between frames, from the loop's process.** `io.print` and
  the backend write to the same output in call order, so a transmission
  written in the update before a frame arrives before that frame's cells.
- **Do not restyle placeholder cells.** Their colour is their address.
- **One placement per id.** `place` replaces the image's placement, so call it
  again when the box changes size. Show one image at two sizes by
  transmitting it under two ids.
- **Every command is quiet** (`q=2`): the terminal sends no `OK` or error.
- Transmission sends the PNG as is (`f=100`), base64 in 4096-byte chunks.

## iTerm2: OSC 1337

`iterm2.draw_at(position, bytes, box)` draws the image at a cell position and
puts the cursor back. The image is not text: it covers the cells it was drawn
over, and etui's buffer does not know it is there. Keep those cells blank in
the buffer, and after the frame:

- draw again after a full repaint (the first frame, and the first after a
  resize), which writes every cell and so erases the image;
- when the box moves, `iterm2.erase` the old box and draw at the new one;
- never draw before the frame, whose cells would overwrite it.
