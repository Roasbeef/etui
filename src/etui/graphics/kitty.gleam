//// The kitty graphics protocol, drawn through Unicode placeholder cells.
////
//// kitty and Ghostty both implement it. An image goes to the terminal once
//// and is shown by text: the app writes the private-use character U+10EEEE
//// into each cell of a box, with combining marks that say which row and
//// column of the image the cell shows and a foreground colour that says which
//// image. The terminal draws that part of the image over the cell. To the
//// rest of etui these are ordinary one-column cells, so the frame differ
//// writes only the ones that changed, a scrolled region carries them along,
//// a clipped box shows the rows that are on screen, and a box that leaves the
//// buffer disappears with the text around it. Nothing has to be placed,
//// moved or deleted at a screen position, which is the point of the design
//// (graphics protocol, "Unicode placeholders", kitty 0.28 and later).
////
//// The life of one image:
////
//// ```gleam
//// let assert Ok(id) = kitty.image_id(7)
//// let box = graphics.Box(columns: 40, rows: 12)
////
//// // Once, after the alternate screen is entered, outside any frame:
//// io.print(kitty.transmit(id, png) <> kitty.place(id, box))
////
//// // In every frame that shows it:
//// buffer.buffer_new(screen) |> kitty.render(geometry.Position(2, 5), id, box)
////
//// // When it is gone for good:
//// io.print(kitty.delete(id))
//// ```
////
//// Three things a caller has to get right:
////
//// - **The alternate screen keeps its own images.** kitty and Ghostty store
////   images per screen, so an image transmitted before the alternate screen
////   is entered is not visible on it. Transmit after the backend has opened.
//// - **The colour is the address.** A placeholder cell's foreground colour
////   is its image id, so restyling the cells afterwards (`buffer.set_style`,
////   a theme pass that remaps colours) points them at a different image or at
////   none. Render placeholders last, and do not recolour them.
//// - **Every command is quiet.** All of them carry `q=2`, so the terminal
////   sends no reply, neither `OK` nor an error, that could arrive among the
////   app's key presses.
////
//// Every placeholder cell carries all three of its diacritics: row, column
//// and the id's high byte. The protocol lets a run of cells leave them out and
//// inherit from the cell to the left, but a diff writes runs that start
//// anywhere, and an inherited cell written without its left neighbour would
//// be read against whatever is on screen beside it. A self-contained cell is
//// correct wherever a patch begins.

import etui/buffer.{type Buffer, Cell, Content}
import etui/geometry.{type Position, Position}
import etui/graphics.{type Box, Box}
import etui/style
import gleam/bit_array
import gleam/int
import gleam/list
import gleam/string

const esc = "\u{001B}"

/// The placeholder character, U+10EEEE, from Supplementary Private Use
/// Area-B.
pub const placeholder = "\u{10EEEE}"

/// The largest row or column a placeholder can address: one per diacritic in
/// kitty's `rowcolumn-diacritics.txt`. A box is clamped to this many cells
/// each way.
pub const max_cells = 297

/// How many bytes of base64 one transmission chunk carries. The protocol
/// allows at most 4096, and requires every chunk but the last to be a
/// multiple of 4 (graphics protocol, "Remote client").
pub const chunk_size = 4096

// 3072 raw bytes encode to exactly 4096 base64 bytes with no padding, so the
// image is cut into raw pieces of this size and each piece encoded alone.
// That is the same text as cutting the encoded whole at every 4096 bytes, and
// it slices a binary instead of a long string.
const raw_chunk_size = 3072

/// An image id: 1 to 4294967295, the protocol's 32-bit range without zero,
/// which the protocol reserves for "no id".
pub opaque type ImageId {
  ImageId(value: Int)
}

/// Validate an image id.
///
/// The id space is shared by everything drawing on the terminal, including
/// other programs in the same kitty window, so an app should pick ids that are
/// unlikely to collide, such as a random 24-bit number.
///
/// ## Examples
///
/// ```gleam
/// kitty.image_id(42)
/// // -> Ok(..)
///
/// kitty.image_id(0)
/// // -> Error(Nil)
/// ```
pub fn image_id(value: Int) -> Result(ImageId, Nil) {
  case value >= 1 && value <= 0xFFFFFFFF {
    True -> Ok(ImageId(value))
    False -> Error(Nil)
  }
}

/// The number an id stands for.
pub fn id_value(id: ImageId) -> Int {
  id.value
}

// ─────────────────────────────────────────────────────────────────
// Commands

/// Transmit a PNG under `id`, without showing it.
///
/// The bytes are sent as they are (`f=100`): the terminal decodes the PNG, so
/// nothing here reads pixels. They are base64-encoded and cut into chunks of
/// `chunk_size`, each its own command, with `m=1` on every chunk but the last
/// and `m=0` on the last. Only the first chunk carries the image's keys; the
/// rest carry `m` and `q`, as the protocol requires.
///
/// Sending a new image under an id that is in use replaces the old one.
///
/// ## Examples
///
/// ```gleam
/// kitty.transmit(id, <<1, 2, 3>>)
/// // -> "\u{1B}_Ga=t,f=100,t=d,i=42,q=2,m=0;AQID\u{1B}\\"
/// ```
pub fn transmit(id: ImageId, png: BitArray) -> String {
  let keys = "a=t,f=100,t=d,i=" <> int.to_string(id.value) <> ",q=2,"
  chunks(png, 0, keys, [])
}

fn chunks(
  png: BitArray,
  offset: Int,
  keys: String,
  rev_out: List(String),
) -> String {
  let left = bit_array.byte_size(png) - offset
  case left <= raw_chunk_size {
    True ->
      [command(keys <> "m=0", encode(png, offset, left)), ..rev_out]
      |> list.reverse
      |> string.concat

    // Every chunk after the first carries only `m` and `q`.
    False ->
      chunks(png, offset + raw_chunk_size, "q=2,", [
        command(keys <> "m=1", encode(png, offset, raw_chunk_size)),
        ..rev_out
      ])
  }
}

// The slice is always inside the binary, since `chunks` derives both bounds
// from its size, so the empty fallback is never taken.
fn encode(png: BitArray, offset: Int, length: Int) -> String {
  case bit_array.slice(png, offset, length) {
    Ok(piece) -> bit_array.base64_encode(piece, True)
    Error(Nil) -> ""
  }
}

/// Create the virtual placement that placeholder cells draw from: `id` fitted
/// into a box of `box.columns` by `box.rows` cells, with its aspect ratio kept
/// and the spare space left empty.
///
/// A virtual placement (`U=1`) draws nothing by itself; the placeholder cells
/// do. It carries placement id 1, so placing the same image again, at a new
/// size after a resize, replaces the placement instead of adding a second one
/// the terminal would have to choose between. An app that shows one image at
/// two sizes at once transmits it under two ids.
///
/// The box is clamped to between 1 and `max_cells` each way, the range the
/// placeholder cells can address.
///
/// ## Examples
///
/// ```gleam
/// kitty.place(id, graphics.Box(columns: 40, rows: 12))
/// // -> "\u{1B}_Ga=p,U=1,i=42,p=1,c=40,r=12,q=2\u{1B}\\"
/// ```
pub fn place(id: ImageId, box: Box) -> String {
  let box = clamp_box(box)
  command(
    "a=p,U=1,i="
      <> int.to_string(id.value)
      <> ",p=1,c="
      <> int.to_string(box.columns)
      <> ",r="
      <> int.to_string(box.rows)
      <> ",q=2",
    "",
  )
}

/// Delete the image `id`, its placements, and its stored data.
///
/// This is the uppercase form (`d=I`), which frees the data as well as the
/// placements. Placeholder cells that still name the id draw nothing once it
/// is gone, so delete after the frame that stops drawing them, or accept that
/// they show blank until it does. The deletion keys that act on screen
/// positions never reach a virtual placement, so the id is the only handle.
///
/// ## Examples
///
/// ```gleam
/// kitty.delete(id)
/// // -> "\u{1B}_Ga=d,d=I,i=42,q=2\u{1B}\\"
/// ```
pub fn delete(id: ImageId) -> String {
  command("a=d,d=I,i=" <> int.to_string(id.value) <> ",q=2", "")
}

// `ESC _ G <keys> ; <payload> ESC \`. A command with no payload ends at the
// keys.
fn command(keys: String, payload: String) -> String {
  let body = case payload {
    "" -> keys
    _ -> keys <> ";" <> payload
  }
  esc <> "_G" <> body <> esc <> "\\"
}

fn clamp_box(box: Box) -> Box {
  Box(
    columns: int.clamp(box.columns, 1, max_cells),
    rows: int.clamp(box.rows, 1, max_cells),
  )
}

// ─────────────────────────────────────────────────────────────────
// Placeholder cells

/// Draw the placeholder cells for `id` in a box whose top-left cell is `at`.
///
/// The box should be the one passed to `place`. Cells outside the buffer are
/// skipped, so a box partly scrolled off the top is drawn by passing a
/// negative `at.y`: the rows that remain on screen still carry their own row
/// numbers, and the terminal shows the lower part of the image.
///
/// The cells overwrite whatever was there. A wide character cut by either
/// edge of the box loses its other half too, so the row around the box still
/// lines up (`buffer.set_cells`).
///
/// ## Examples
///
/// ```gleam
/// buffer.buffer_new(screen)
/// |> kitty.render(geometry.Position(x: 2, y: 5), id, graphics.Box(40, 12))
/// ```
pub fn render(buf: Buffer, at: Position, id: ImageId, box: Box) -> Buffer {
  let box = clamp_box(box)
  let s = id_style(id)

  // Built newest first and written in one pass; the order of writes does not
  // matter, since no two cells share a position.
  let cells =
    int.range(from: 0, to: box.rows, with: [], run: fn(acc, row) {
      int.range(from: 0, to: box.columns, with: acc, run: fn(acc, column) {
        [
          #(
            Position(x: at.x + column, y: at.y + row),
            Cell(
              content: Content(symbol: cell_symbol(id, row, column), width: 1),
              style: s,
              link: "",
            ),
          ),
          ..acc
        ]
      })
    })
  buffer.set_cells(buf, cells)
}

/// The text of one placeholder cell: U+10EEEE, the row diacritic, the column
/// diacritic, and the diacritic for the id's most significant byte.
///
/// Out-of-range coordinates are clamped to the last addressable one rather
/// than failing, since `render` never produces them.
///
/// ## Examples
///
/// ```gleam
/// kitty.cell_symbol(id, 0, 1)
/// // -> "\u{10EEEE}\u{0305}\u{030D}\u{0305}"
/// ```
pub fn cell_symbol(id: ImageId, row: Int, column: Int) -> String {
  placeholder
  <> diacritic(row)
  <> diacritic(column)
  <> diacritic(int.bitwise_shift_right(id.value, 24))
}

/// The style of every placeholder cell for `id`: the low 24 bits of the id as
/// a true-colour foreground, red the most significant byte. The high byte
/// travels in the third diacritic.
///
/// True colour rather than the 256-colour palette, because an indexed colour
/// carries only eight bits, and because indices 0 to 15 are written as the
/// short SGR forms, which the protocol does not read as an id.
pub fn id_style(id: ImageId) -> style.Style {
  let v = id.value
  style.new(
    style.Rgb(
      int.bitwise_and(int.bitwise_shift_right(v, 16), 0xFF),
      int.bitwise_and(int.bitwise_shift_right(v, 8), 0xFF),
      int.bitwise_and(v, 0xFF),
    ),
    style.Default,
    style.none(),
  )
}

/// The combining mark for the number `n`, from kitty's
/// `rowcolumn-diacritics.txt`: U+0305 for 0, U+030D for 1, and so on.
/// `n` is clamped to `0..max_cells - 1`.
///
/// ## Examples
///
/// ```gleam
/// kitty.diacritic(2)
/// // -> "\u{030E}"
/// ```
pub fn diacritic(n: Int) -> String {
  // Every entry in the table is a valid scalar value and `n` is clamped into
  // the table, so the empty fallback is never taken.
  case
    string.utf_codepoint(diacritic_codepoint(int.clamp(n, 0, max_cells - 1)))
  {
    Ok(cp) -> string.from_utf_codepoints([cp])
    Error(Nil) -> ""
  }
}

// kitty's gen/rowcolumn-diacritics.txt, in order: Unicode 6.0 combining marks
// of class 230 with no decomposition, less a few that normalisation can fuse
// with a base. The index is the number the mark stands for. Generated from
// that file, not typed; regenerate it from the file rather than editing it.
fn diacritic_codepoint(n: Int) -> Int {
  case n {
    0 -> 0x0305
    1 -> 0x030D
    2 -> 0x030E
    3 -> 0x0310
    4 -> 0x0312
    5 -> 0x033D
    6 -> 0x033E
    7 -> 0x033F
    8 -> 0x0346
    9 -> 0x034A
    10 -> 0x034B
    11 -> 0x034C
    12 -> 0x0350
    13 -> 0x0351
    14 -> 0x0352
    15 -> 0x0357
    16 -> 0x035B
    17 -> 0x0363
    18 -> 0x0364
    19 -> 0x0365
    20 -> 0x0366
    21 -> 0x0367
    22 -> 0x0368
    23 -> 0x0369
    24 -> 0x036A
    25 -> 0x036B
    26 -> 0x036C
    27 -> 0x036D
    28 -> 0x036E
    29 -> 0x036F
    30 -> 0x0483
    31 -> 0x0484
    32 -> 0x0485
    33 -> 0x0486
    34 -> 0x0487
    35 -> 0x0592
    36 -> 0x0593
    37 -> 0x0594
    38 -> 0x0595
    39 -> 0x0597
    40 -> 0x0598
    41 -> 0x0599
    42 -> 0x059C
    43 -> 0x059D
    44 -> 0x059E
    45 -> 0x059F
    46 -> 0x05A0
    47 -> 0x05A1
    48 -> 0x05A8
    49 -> 0x05A9
    50 -> 0x05AB
    51 -> 0x05AC
    52 -> 0x05AF
    53 -> 0x05C4
    54 -> 0x0610
    55 -> 0x0611
    56 -> 0x0612
    57 -> 0x0613
    58 -> 0x0614
    59 -> 0x0615
    60 -> 0x0616
    61 -> 0x0617
    62 -> 0x0657
    63 -> 0x0658
    64 -> 0x0659
    65 -> 0x065A
    66 -> 0x065B
    67 -> 0x065D
    68 -> 0x065E
    69 -> 0x06D6
    70 -> 0x06D7
    71 -> 0x06D8
    72 -> 0x06D9
    73 -> 0x06DA
    74 -> 0x06DB
    75 -> 0x06DC
    76 -> 0x06DF
    77 -> 0x06E0
    78 -> 0x06E1
    79 -> 0x06E2
    80 -> 0x06E4
    81 -> 0x06E7
    82 -> 0x06E8
    83 -> 0x06EB
    84 -> 0x06EC
    85 -> 0x0730
    86 -> 0x0732
    87 -> 0x0733
    88 -> 0x0735
    89 -> 0x0736
    90 -> 0x073A
    91 -> 0x073D
    92 -> 0x073F
    93 -> 0x0740
    94 -> 0x0741
    95 -> 0x0743
    96 -> 0x0745
    97 -> 0x0747
    98 -> 0x0749
    99 -> 0x074A
    100 -> 0x07EB
    101 -> 0x07EC
    102 -> 0x07ED
    103 -> 0x07EE
    104 -> 0x07EF
    105 -> 0x07F0
    106 -> 0x07F1
    107 -> 0x07F3
    108 -> 0x0816
    109 -> 0x0817
    110 -> 0x0818
    111 -> 0x0819
    112 -> 0x081B
    113 -> 0x081C
    114 -> 0x081D
    115 -> 0x081E
    116 -> 0x081F
    117 -> 0x0820
    118 -> 0x0821
    119 -> 0x0822
    120 -> 0x0823
    121 -> 0x0825
    122 -> 0x0826
    123 -> 0x0827
    124 -> 0x0829
    125 -> 0x082A
    126 -> 0x082B
    127 -> 0x082C
    128 -> 0x082D
    129 -> 0x0951
    130 -> 0x0953
    131 -> 0x0954
    132 -> 0x0F82
    133 -> 0x0F83
    134 -> 0x0F86
    135 -> 0x0F87
    136 -> 0x135D
    137 -> 0x135E
    138 -> 0x135F
    139 -> 0x17DD
    140 -> 0x193A
    141 -> 0x1A17
    142 -> 0x1A75
    143 -> 0x1A76
    144 -> 0x1A77
    145 -> 0x1A78
    146 -> 0x1A79
    147 -> 0x1A7A
    148 -> 0x1A7B
    149 -> 0x1A7C
    150 -> 0x1B6B
    151 -> 0x1B6D
    152 -> 0x1B6E
    153 -> 0x1B6F
    154 -> 0x1B70
    155 -> 0x1B71
    156 -> 0x1B72
    157 -> 0x1B73
    158 -> 0x1CD0
    159 -> 0x1CD1
    160 -> 0x1CD2
    161 -> 0x1CDA
    162 -> 0x1CDB
    163 -> 0x1CE0
    164 -> 0x1DC0
    165 -> 0x1DC1
    166 -> 0x1DC3
    167 -> 0x1DC4
    168 -> 0x1DC5
    169 -> 0x1DC6
    170 -> 0x1DC7
    171 -> 0x1DC8
    172 -> 0x1DC9
    173 -> 0x1DCB
    174 -> 0x1DCC
    175 -> 0x1DD1
    176 -> 0x1DD2
    177 -> 0x1DD3
    178 -> 0x1DD4
    179 -> 0x1DD5
    180 -> 0x1DD6
    181 -> 0x1DD7
    182 -> 0x1DD8
    183 -> 0x1DD9
    184 -> 0x1DDA
    185 -> 0x1DDB
    186 -> 0x1DDC
    187 -> 0x1DDD
    188 -> 0x1DDE
    189 -> 0x1DDF
    190 -> 0x1DE0
    191 -> 0x1DE1
    192 -> 0x1DE2
    193 -> 0x1DE3
    194 -> 0x1DE4
    195 -> 0x1DE5
    196 -> 0x1DE6
    197 -> 0x1DFE
    198 -> 0x20D0
    199 -> 0x20D1
    200 -> 0x20D4
    201 -> 0x20D5
    202 -> 0x20D6
    203 -> 0x20D7
    204 -> 0x20DB
    205 -> 0x20DC
    206 -> 0x20E1
    207 -> 0x20E7
    208 -> 0x20E9
    209 -> 0x20F0
    210 -> 0x2CEF
    211 -> 0x2CF0
    212 -> 0x2CF1
    213 -> 0x2DE0
    214 -> 0x2DE1
    215 -> 0x2DE2
    216 -> 0x2DE3
    217 -> 0x2DE4
    218 -> 0x2DE5
    219 -> 0x2DE6
    220 -> 0x2DE7
    221 -> 0x2DE8
    222 -> 0x2DE9
    223 -> 0x2DEA
    224 -> 0x2DEB
    225 -> 0x2DEC
    226 -> 0x2DED
    227 -> 0x2DEE
    228 -> 0x2DEF
    229 -> 0x2DF0
    230 -> 0x2DF1
    231 -> 0x2DF2
    232 -> 0x2DF3
    233 -> 0x2DF4
    234 -> 0x2DF5
    235 -> 0x2DF6
    236 -> 0x2DF7
    237 -> 0x2DF8
    238 -> 0x2DF9
    239 -> 0x2DFA
    240 -> 0x2DFB
    241 -> 0x2DFC
    242 -> 0x2DFD
    243 -> 0x2DFE
    244 -> 0x2DFF
    245 -> 0xA66F
    246 -> 0xA67C
    247 -> 0xA67D
    248 -> 0xA6F0
    249 -> 0xA6F1
    250 -> 0xA8E0
    251 -> 0xA8E1
    252 -> 0xA8E2
    253 -> 0xA8E3
    254 -> 0xA8E4
    255 -> 0xA8E5
    256 -> 0xA8E6
    257 -> 0xA8E7
    258 -> 0xA8E8
    259 -> 0xA8E9
    260 -> 0xA8EA
    261 -> 0xA8EB
    262 -> 0xA8EC
    263 -> 0xA8ED
    264 -> 0xA8EE
    265 -> 0xA8EF
    266 -> 0xA8F0
    267 -> 0xA8F1
    268 -> 0xAAB0
    269 -> 0xAAB2
    270 -> 0xAAB3
    271 -> 0xAAB7
    272 -> 0xAAB8
    273 -> 0xAABE
    274 -> 0xAABF
    275 -> 0xAAC1
    276 -> 0xFE20
    277 -> 0xFE21
    278 -> 0xFE22
    279 -> 0xFE23
    280 -> 0xFE24
    281 -> 0xFE25
    282 -> 0xFE26
    283 -> 0x10A0F
    284 -> 0x10A38
    285 -> 0x1D185
    286 -> 0x1D186
    287 -> 0x1D187
    288 -> 0x1D188
    289 -> 0x1D189
    290 -> 0x1D1AA
    291 -> 0x1D1AB
    292 -> 0x1D1AC
    293 -> 0x1D1AD
    294 -> 0x1D242
    295 -> 0x1D243
    296 -> 0x1D244
    _ -> -1
  }
}
