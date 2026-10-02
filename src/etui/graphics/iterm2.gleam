//// iTerm2 inline images (OSC 1337), the fallback protocol.
////
//// iTerm2 draws an image at the cursor, over a box of cells, when it receives
//// `OSC 1337 ; File=inline=1;... : <base64> BEL`. Unlike kitty's placeholder
//// cells this is not text: the image is attached to the screen cells it
//// covered when it was drawn, and etui's buffer knows nothing about it. The
//// buffer still holds whatever the app put in those cells, which should be
//// blanks, and the frame differ leaves unchanged blanks alone, so the image
//// survives ordinary frames. Three things remove or misplace it:
////
//// - **A full repaint.** The first frame, and the first frame after a resize,
////   writes every cell, and a character written into an image cell replaces
////   that part of the image. Draw the image again after any such frame.
//// - **A move.** When the box moves (a scroll, a layout change) the image
////   stays where it was drawn. Erase the old box (`erase`) and draw at the new
////   position, both after the frame that moved it. etui's full-screen diff can
////   move rows with a terminal scroll, which takes the image along with the
////   rows; erasing and redrawing is still correct then, only redundant.
//// - **Text written into the box.** The app's own cells win. Keep the box
////   blank in the buffer for as long as the image is meant to show.
////
//// So a caller redraws after the frame, never before it: draw the frame,
//// then write `erase` for a box that moved and `draw_at` for each box that
//// was repainted, moved or newly shown. Both save and restore the cursor, so
//// the frame's own cursor placement survives them.
////
//// Sequences are as documented at iterm2.com/documentation-images.html.
//// `doNotMoveCursor` needs iTerm2 3.5; earlier versions move the cursor
//// after the image, which the surrounding save and restore undoes anyway.

import etui/geometry.{type Position}
import etui/graphics.{type Box}
import gleam/bit_array
import gleam/int
import gleam/list
import gleam/string

const esc = "\u{001B}"

/// The OSC 1337 sequence that draws `image` at the cursor, scaled into a box
/// of `box.columns` by `box.rows` cells with its aspect ratio kept.
///
/// `image` is the file's bytes: any format macOS can decode, PNG and JPEG
/// among them. A bare number for `width` and `height` is a count of cells in
/// the protocol, which is how the box is expressed here.
///
/// ## Examples
///
/// ```gleam
/// iterm2.inline(<<1, 2, 3>>, graphics.Box(columns: 10, rows: 4))
/// // -> "\u{1B}]1337;File=inline=1;size=3;width=10;height=4;preserveAspectRatio=1;doNotMoveCursor=1:AQID\u{07}"
/// ```
pub fn inline(image: BitArray, box: Box) -> String {
  esc
  <> "]1337;File=inline=1;size="
  <> int.to_string(bit_array.byte_size(image))
  <> ";width="
  <> int.to_string(int.max(box.columns, 1))
  <> ";height="
  <> int.to_string(int.max(box.rows, 1))
  <> ";preserveAspectRatio=1;doNotMoveCursor=1:"
  <> bit_array.base64_encode(image, True)
  <> "\u{0007}"
}

/// Draw `image` with its top-left cell at `at` (0-based), leaving the cursor
/// where it was.
///
/// ## Examples
///
/// ```gleam
/// // After the frame that laid the box out at column 2, row 5:
/// io.print(iterm2.draw_at(geometry.Position(2, 5), png, box))
/// ```
pub fn draw_at(at: Position, image: BitArray, box: Box) -> String {
  esc <> "7" <> move_to(at) <> inline(image, box) <> esc <> "8"
}

/// Blank the cells of a box, which removes the part of any inline image that
/// covers them, leaving the cursor where it was.
///
/// Each row is erased with ECH (`CSI n X`), which clears cells without moving
/// the cursor or the text to their right. The rendition is reset first so
/// the cleared cells take the default background, as the buffer's blanks do.
///
/// ## Examples
///
/// ```gleam
/// iterm2.erase(geometry.Position(2, 5), graphics.Box(columns: 3, rows: 2))
/// // -> "\u{1B}7\u{1B}[0m\u{1B}[6;3H\u{1B}[3X\u{1B}[7;3H\u{1B}[3X\u{1B}8"
/// ```
pub fn erase(at: Position, box: Box) -> String {
  let columns = int.max(box.columns, 0)
  let rows =
    int.range(from: 0, to: int.max(box.rows, 0), with: [], run: fn(acc, row) {
      [
        move_to(geometry.Position(..at, y: at.y + row))
          <> esc
          <> "["
          <> int.to_string(columns)
          <> "X",
        ..acc
      ]
    })
  esc <> "7" <> esc <> "[0m" <> string.concat(list.reverse(rows)) <> esc <> "8"
}

fn move_to(at: Position) -> String {
  esc <> "[" <> int.to_string(at.y + 1) <> ";" <> int.to_string(at.x + 1) <> "H"
}
