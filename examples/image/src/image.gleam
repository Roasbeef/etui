//// Show a PNG inline, the way an app would: probe the terminal at launch,
//// then draw the image in a box that follows the window as it resizes.
////
//// ```sh
//// cd examples/image
//// gleam run                      # etui's logo
//// gleam run -- path/to/file.png  # any PNG
//// ```
////
//// In kitty or Ghostty the image is drawn through placeholder cells; in
//// iTerm2 with OSC 1337 after each frame that moves it; anywhere else, and
//// inside Herdr or under `NO_COLOR`, as a line of text saying why not. `q`
//// quits, and the terminal's answer is printed after the app exits.

import etui/backend
import etui/backend/default
import etui/buffer
import etui/geometry.{type Rect}
import etui/graphics.{type Box, type Capabilities, Box, CellSize}
import etui/graphics/iterm2
import etui/graphics/kitty
import etui/graphics/probe
import etui/terminal
import etui/widgets/block
import etui/widgets/paragraph
import gleam/int
import gleam/io
import gleam/option.{None, Some}
import gleam/string

@external(erlang, "image_ffi", "arguments")
fn arguments() -> List(String)

@external(erlang, "image_ffi", "getenv")
fn getenv(name: String) -> Result(String, Nil)

@external(erlang, "image_ffi", "read_file")
fn read_file(path: String) -> Result(BitArray, Nil)

/// What the loop knows: the image, what the terminal can do with it, and the
/// box it was last placed or drawn in, so a resize is noticed.
type State {
  State(
    png: BitArray,
    size: #(Int, Int),
    caps: Capabilities,
    decision: graphics.Decision,
    id: kitty.ImageId,
    shown: Result(#(Rect, Box), Nil),
  )
}

pub fn main() {
  let path = case arguments() {
    [p, ..] -> p
    [] -> "../../assets/logo.png"
  }
  case read_file(path), kitty.image_id(4_242_424) {
    Ok(png), Ok(id) -> show(png, id)
    Error(Nil), _ -> io.println("cannot read " <> path)
    _, Error(Nil) -> io.println("bad image id")
  }
}

fn show(png: BitArray, id: kitty.ImageId) -> Nil {
  // The probe goes first, before the alternate screen, and only when the
  // environment does not rule it out.
  let decision = graphics.decide(getenv)
  let caps = case decision {
    graphics.Probe -> probe.run(200)
    graphics.Skip(_) -> graphics.none()
  }
  case terminal.new(default.new()) {
    Error(_) -> io.println("no terminal")
    Ok(term) -> {
      // kitty keeps the alternate screen's images apart from the main
      // screen's, so the image goes over only now that the backend is open.
      case graphics.protocol(caps) {
        graphics.Kitty -> io.print(kitty.transmit(id, png))
        _ -> Nil
      }
      let state =
        State(
          png: png,
          size: png_size(png),
          caps: caps,
          decision: decision,
          id: id,
          shown: Error(Nil),
        )
      let #(state, term) = loop(term, state)
      case graphics.protocol(caps) {
        graphics.Kitty -> io.print(kitty.delete(state.id))
        _ -> Nil
      }
      terminal.restore(term)
      io.println(describe(caps, decision))
    }
  }
}

fn loop(
  term: terminal.Terminal(s),
  state: State,
) -> #(State, terminal.Terminal(s)) {
  let screen = terminal.area(term)
  let #(inner, box) = layout(state, screen)
  let moved = state.shown != Ok(#(inner, box))

  // A new box needs a new virtual placement before the frame that draws its
  // cells; the placement replaces the previous one.
  case graphics.protocol(state.caps), moved {
    graphics.Kitty, True -> io.print(kitty.place(state.id, box))
    _, _ -> Nil
  }
  let drawn = terminal.draw(term, fn(frame) { view(frame, state, inner, box) })
  let term = case drawn {
    Ok(t) -> t
    Error(_) -> term
  }

  // iTerm2 draws over the cells after the frame, and only when the frame
  // repainted or moved them; the blank cells underneath keep it otherwise.
  case graphics.protocol(state.caps), moved {
    graphics.Iterm2, True -> {
      case state.shown {
        Ok(#(old, old_box)) -> io.print(iterm2.erase(old.position, old_box))
        Error(Nil) -> Nil
      }
      io.print(iterm2.draw_at(inner.position, state.png, box))
    }
    _, _ -> Nil
  }
  let state = State(..state, shown: Ok(#(inner, box)))
  case terminal.poll(term, 100) {
    Ok(#(backend.KeyPress("q"), term)) -> #(state, term)

    // A resize repaints every cell, which wipes an iTerm2 image, so forget
    // where it was drawn and the next pass draws it again.
    Ok(#(backend.Resize(_, _), term)) ->
      loop(term, State(..state, shown: Error(Nil)))
    Ok(#(_, term)) -> loop(term, state)
    Error(_) -> #(state, term)
  }
}

// The image sits in a bordered block, fitted to what is left of the screen.
fn layout(state: State, screen: Rect) -> #(Rect, Box) {
  let #(w, h) = state.size
  let cell = case state.caps.cell_size {
    Some(c) -> c
    None -> CellSize(width: 8, height: 16)
  }
  let max = Box(columns: screen.size.width - 4, rows: screen.size.height - 5)
  let box = graphics.fit(w, h, cell, max)
  let inner = geometry.rect_new(2, 2, box.columns, box.rows)
  #(inner, box)
}

fn view(
  frame: terminal.Frame,
  state: State,
  inner: Rect,
  box: Box,
) -> terminal.Frame {
  let outline =
    geometry.rect_new(
      inner.position.x - 1,
      inner.position.y - 1,
      box.columns + 2,
      box.rows + 2,
    )
  let #(w, h) = state.size
  let title =
    "image/png " <> int.to_string(w) <> "x" <> int.to_string(h) <> " · q quits"
  let blk =
    block.block_new()
    |> block.with_border(block.Rounded)
    |> block.with_title(title, block.Top)
  let buf =
    buffer.buffer_new(frame.area)
    |> block.render(outline, blk)
  let buf = case graphics.protocol(state.caps) {
    // Placeholders last, so nothing restyles them.
    graphics.Kitty -> kitty.render(buf, inner.position, state.id, box)
    graphics.Iterm2 -> buf
    graphics.TextOnly ->
      paragraph.render(
        buf,
        inner,
        paragraph.paragraph_new(describe(state.caps, state.decision)),
      )
  }
  terminal.with_buffer(frame, buf)
}

fn describe(caps: Capabilities, decision: graphics.Decision) -> String {
  let support = fn(s) {
    case s {
      graphics.Supported -> "yes"
      graphics.Unsupported -> "no"
    }
  }
  let cell = case caps.cell_size {
    Some(c) -> int.to_string(c.width) <> "x" <> int.to_string(c.height) <> " px"
    None -> "unknown"
  }
  let name = option.unwrap(caps.terminal, "no version reply")
  case decision {
    graphics.Probe ->
      string.join(
        [
          "kitty graphics: " <> support(caps.kitty),
          "iTerm2 images: " <> support(caps.iterm2),
          "cell: " <> cell,
          "terminal: " <> name,
        ],
        " · ",
      )
    graphics.Skip(graphics.InsideHerdr) -> "not probed inside Herdr; no image"
    graphics.Skip(graphics.ColourDisabled) ->
      "not probed under NO_COLOR; no image"
  }
}

// A PNG's width and height are the first two fields of its IHDR chunk, which
// always comes first, right after the eight-byte signature.
fn png_size(png: BitArray) -> #(Int, Int) {
  case png {
    <<0x89, 0x50, 0x4E, 0x47, _:bytes-size(12), w:size(32), h:size(32), _:bits>> -> #(
      w,
      h,
    )
    _ -> #(0, 0)
  }
}
