//// kitty transmission and placeholder cells, iTerm2 inline images, and
//// fitting an image to a cell box. Every sequence is checked byte for byte,
//// since a terminal that receives a malformed graphics command shows nothing
//// and says nothing (all of these are sent in quiet mode).

import etui/buffer
import etui/geometry.{Position, rect_new}
import etui/graphics.{Box, CellSize}
import etui/graphics/iterm2
import etui/graphics/kitty
import etui/style
import etui/text
import gleam/bit_array
import gleam/int
import gleam/list
import gleam/set
import gleam/string
import gleeunit/should

const esc = "\u{001B}"

fn id(n: Int) -> kitty.ImageId {
  case kitty.image_id(n) {
    Ok(i) -> i
    Error(Nil) -> panic as "test id out of range"
  }
}

// ─────────────────────────────────────────────────────────────────
// Ids

pub fn image_ids_are_one_to_two_to_the_32_minus_one_test() {
  kitty.image_id(0) |> should.equal(Error(Nil))
  kitty.image_id(-1) |> should.equal(Error(Nil))
  kitty.image_id(0x100000000) |> should.equal(Error(Nil))
  kitty.id_value(id(1)) |> should.equal(1)
  kitty.id_value(id(0xFFFFFFFF)) |> should.equal(0xFFFFFFFF)
}

// ─────────────────────────────────────────────────────────────────
// Transmission

pub fn a_small_png_is_one_quiet_chunk_test() {
  kitty.transmit(id(42), <<1, 2, 3>>)
  |> should.equal(esc <> "_Ga=t,f=100,t=d,i=42,q=2,m=0;AQID" <> esc <> "\\")
}

pub fn an_empty_payload_is_still_one_well_formed_command_test() {
  kitty.transmit(id(42), <<>>)
  |> should.equal(esc <> "_Ga=t,f=100,t=d,i=42,q=2,m=0" <> esc <> "\\")
}

// Splits a transmission back into its commands' key and payload halves.
fn commands(bytes: String) -> List(#(String, String)) {
  string.split(bytes, esc <> "\\")
  |> list.filter(fn(s) { s != "" })
  |> list.map(fn(s) {
    let assert "\u{001B}_G" <> body = s as "every command starts with APC G"
    case string.split_once(body, ";") {
      Ok(pair) -> pair
      Error(Nil) -> #(body, "")
    }
  })
}

fn bytes(n: Int) -> BitArray {
  inclusive(0, n - 1)
  |> list.fold(<<>>, fn(acc, i) { <<acc:bits, { i % 251 }:8>> })
}

pub fn exactly_one_chunk_of_base64_is_not_split_test() {
  // 3072 raw bytes are exactly 4096 base64 bytes.
  let cmds = commands(kitty.transmit(id(9), bytes(3072)))
  list.length(cmds) |> should.equal(1)
  let assert [#(keys, payload)] = cmds as "one command"
  keys |> should.equal("a=t,f=100,t=d,i=9,q=2,m=0")
  string.length(payload) |> should.equal(4096)
}

pub fn one_byte_over_the_boundary_makes_a_second_chunk_test() {
  let png = bytes(3073)
  let cmds = commands(kitty.transmit(id(9), png))
  let assert [#(first_keys, first), #(last_keys, last)] = cmds as "two"
  first_keys |> should.equal("a=t,f=100,t=d,i=9,q=2,m=1")
  last_keys |> should.equal("q=2,m=0")
  string.length(first) |> should.equal(kitty.chunk_size)
  string.length(last) |> should.equal(4)

  // The chunks concatenate to the encoding of the whole image.
  { first <> last } |> should.equal(bit_array.base64_encode(png, True))
}

pub fn a_large_image_is_full_chunks_then_the_rest_test() {
  let png = bytes(3072 * 3 + 10)
  let cmds = commands(kitty.transmit(id(9), png))
  list.length(cmds) |> should.equal(4)
  list.map(cmds, fn(c) { c.0 })
  |> should.equal(["a=t,f=100,t=d,i=9,q=2,m=1", "q=2,m=1", "q=2,m=1", "q=2,m=0"])

  // Every chunk but the last is 4096 bytes, a multiple of 4.
  list.map(cmds, fn(c) { string.length(c.1) })
  |> should.equal([4096, 4096, 4096, 16])
  list.map(cmds, fn(c) { c.1 })
  |> string.concat
  |> should.equal(bit_array.base64_encode(png, True))
}

// ─────────────────────────────────────────────────────────────────
// Placement and deletion

pub fn place_makes_one_quiet_virtual_placement_test() {
  kitty.place(id(42), Box(columns: 40, rows: 12))
  |> should.equal(esc <> "_Ga=p,U=1,i=42,p=1,c=40,r=12,q=2" <> esc <> "\\")
}

pub fn place_clamps_the_box_to_what_placeholders_can_address_test() {
  kitty.place(id(1), Box(columns: 0, rows: 1000))
  |> should.equal(esc <> "_Ga=p,U=1,i=1,p=1,c=1,r=297,q=2" <> esc <> "\\")
}

pub fn delete_frees_the_image_by_id_test() {
  kitty.delete(id(42))
  |> should.equal(esc <> "_Ga=d,d=I,i=42,q=2" <> esc <> "\\")
}

// ─────────────────────────────────────────────────────────────────
// Diacritics

pub fn the_diacritic_table_matches_kitty_test() {
  // The ends and a few interior entries of rowcolumn-diacritics.txt.
  kitty.diacritic(0) |> should.equal("\u{0305}")
  kitty.diacritic(1) |> should.equal("\u{030D}")
  kitty.diacritic(2) |> should.equal("\u{030E}")
  kitty.diacritic(30) |> should.equal("\u{0483}")
  kitty.diacritic(255) |> should.equal("\u{A8E5}")
  kitty.diacritic(296) |> should.equal("\u{1D244}")
}

pub fn every_diacritic_is_distinct_test() {
  inclusive(0, kitty.max_cells - 1)
  |> list.map(kitty.diacritic)
  |> set.from_list
  |> set.size
  |> should.equal(kitty.max_cells)
}

pub fn diacritics_clamp_out_of_range_numbers_test() {
  kitty.diacritic(-5) |> should.equal(kitty.diacritic(0))
  kitty.diacritic(5000) |> should.equal(kitty.diacritic(296))
}

// ─────────────────────────────────────────────────────────────────
// Placeholder cells

pub fn a_cell_names_its_row_column_and_high_byte_test() {
  kitty.cell_symbol(id(42), 0, 1)
  |> should.equal("\u{10EEEE}\u{0305}\u{030D}\u{0305}")

  // The protocol's own example: id 33554474 is 42 plus 2 in the high byte.
  kitty.cell_symbol(id(33_554_474), 1, 0)
  |> should.equal("\u{10EEEE}\u{030D}\u{0305}\u{030E}")
}

pub fn the_low_24_bits_are_the_foreground_test() {
  kitty.id_style(id(42)).fg |> should.equal(style.Rgb(0, 0, 42))
  kitty.id_style(id(0x123456)).fg |> should.equal(style.Rgb(0x12, 0x34, 0x56))
  kitty.id_style(id(33_554_474)).fg |> should.equal(style.Rgb(0, 0, 42))
}

pub fn every_placeholder_and_its_marks_are_one_grapheme_one_cell_test() {
  // The width tables and the grapheme segmenter both have to agree, on both
  // targets, that a placeholder with any of its marks is one column.
  inclusive(0, kitty.max_cells - 1)
  |> list.each(fn(n) {
    let s = kitty.cell_symbol(id(0xFF000001), n, kitty.max_cells - 1 - n)
    string.to_graphemes(s) |> should.equal([s])
    text.cell_width(s) |> should.equal(1)
  })
}

fn placeholder_box() -> buffer.Buffer {
  buffer.buffer_new(rect_new(0, 0, 6, 4))
  |> kitty.render(Position(1, 1), id(42), Box(columns: 3, rows: 2))
}

pub fn render_fills_the_box_with_addressed_cells_test() {
  let buf = placeholder_box()
  list.each([0, 1], fn(row) {
    list.each([0, 1, 2], fn(column) {
      let cell = buffer.get_cell(buf, Position(1 + column, 1 + row))
      buffer.cell_symbol(cell)
      |> should.equal(kitty.cell_symbol(id(42), row, column))
      buffer.cell_fg(cell) |> should.equal(style.Rgb(0, 0, 42))
      buffer.is_continuation(cell) |> should.be_false
    })
  })

  // Nothing outside the box is touched.
  buffer.get_cell(buf, Position(0, 1)) |> should.equal(buffer.empty_cell())
  buffer.get_cell(buf, Position(4, 1)) |> should.equal(buffer.empty_cell())
  buffer.get_cell(buf, Position(1, 0)) |> should.equal(buffer.empty_cell())
}

pub fn a_rendered_row_is_as_many_columns_as_the_box_test() {
  // The terminal advances one column per placeholder cell, so the text after
  // the box lands where the buffer put it.
  let row =
    inclusive(0, 2)
    |> list.map(fn(c) { kitty.cell_symbol(id(42), 0, c) })
    |> string.concat
  text.cell_width(row) |> should.equal(3)
}

pub fn the_full_paint_is_exact_test() {
  let buf =
    buffer.buffer_new(rect_new(0, 0, 2, 2))
    |> kitty.render(Position(0, 0), id(42), Box(columns: 2, rows: 2))
  let p = fn(r, c) { kitty.cell_symbol(id(42), r, c) }
  buffer.to_ansi(buf)
  |> should.equal(
    esc
    <> "[1;1H"
    <> esc
    <> "[38;2;0;0;42m"
    <> p(0, 0)
    <> p(0, 1)
    <> esc
    <> "[2;1H"
    <> p(1, 0)
    <> p(1, 1)
    <> esc
    <> "[0m",
  )
}

pub fn a_diff_into_the_middle_of_a_box_is_self_contained_test() {
  // Swap one cell for another image's: the patch starts mid-row and carries
  // the full colour and all three marks, so nothing depends on the cell to
  // its left on screen.
  let before = placeholder_box()
  let after =
    buffer.set_cell(
      before,
      Position(2, 2),
      buffer.Cell(
        content: buffer.Content(
          symbol: kitty.cell_symbol(id(7), 1, 1),
          width: 1,
        ),
        style: kitty.id_style(id(7)),
        link: "",
      ),
    )
  buffer.diff_to_ansi(before, after)
  |> should.equal(
    esc
    <> "[3;3H"
    <> esc
    <> "[38;2;0;0;7m"
    <> kitty.cell_symbol(id(7), 1, 1)
    <> esc
    <> "[0m",
  )
}

pub fn a_box_scrolled_off_the_top_keeps_its_row_numbers_test() {
  let buf =
    buffer.buffer_new(rect_new(0, 0, 4, 3))
    |> kitty.render(Position(0, -2), id(42), Box(columns: 2, rows: 4))

  // Rows 2 and 3 of the image are on screen rows 0 and 1.
  buffer.cell_symbol(buffer.get_cell(buf, Position(1, 0)))
  |> should.equal(kitty.cell_symbol(id(42), 2, 1))
  buffer.cell_symbol(buffer.get_cell(buf, Position(0, 1)))
  |> should.equal(kitty.cell_symbol(id(42), 3, 0))
  buffer.get_cell(buf, Position(0, 2)) |> should.equal(buffer.empty_cell())
}

pub fn a_box_edge_through_wide_text_blanks_the_cut_halves_test() {
  // "你好你" fills columns 0..5. A box over columns 1..2 cuts the first
  // character's right half and the second's left half; the third is whole.
  let buf =
    buffer.buffer_new(rect_new(0, 0, 6, 1))
    |> buffer.set_string(Position(0, 0), "你好你", style.default_style())
    |> kitty.render(Position(1, 0), id(42), Box(columns: 2, rows: 1))
  buffer.get_cell(buf, Position(0, 0)) |> should.equal(buffer.empty_cell())
  buffer.get_cell(buf, Position(3, 0)) |> should.equal(buffer.empty_cell())
  buffer.cell_symbol(buffer.get_cell(buf, Position(4, 0))) |> should.equal("你")
  buffer.is_continuation(buffer.get_cell(buf, Position(5, 0)))
  |> should.be_true

  // The row draws as six columns: blank, two placeholders, blank, and the
  // untouched wide character.
  let drawn =
    inclusive(0, 5)
    |> list.filter(fn(x) {
      !buffer.is_continuation(buffer.get_cell(buf, Position(x, 0)))
    })
    |> list.map(fn(x) {
      buffer.cell_symbol(buffer.get_cell(buf, Position(x, 0)))
    })
    |> string.concat
  text.cell_width(drawn) |> should.equal(6)
}

pub fn placeholder_text_written_as_a_string_lays_out_one_cell_each_test() {
  // A caller that builds rows as text (spans, set_string) goes through the
  // native fill path on Erlang; it must agree with render.
  let row =
    inclusive(0, 3)
    |> list.map(fn(c) { kitty.cell_symbol(id(42), 0, c) })
    |> string.concat
  let buf =
    buffer.buffer_new(rect_new(0, 0, 5, 1))
    |> buffer.set_string(Position(0, 0), row <> "x", kitty.id_style(id(42)))
  list.each([0, 1, 2, 3], fn(c) {
    buffer.cell_symbol(buffer.get_cell(buf, Position(c, 0)))
    |> should.equal(kitty.cell_symbol(id(42), 0, c))
  })
  buffer.cell_symbol(buffer.get_cell(buf, Position(4, 0))) |> should.equal("x")
}

// ─────────────────────────────────────────────────────────────────
// iTerm2

pub fn iterm2_inline_is_sized_in_cells_test() {
  iterm2.inline(<<1, 2, 3>>, Box(columns: 10, rows: 4))
  |> should.equal(
    esc
    <> "]1337;File=inline=1;size=3;width=10;height=4;preserveAspectRatio=1;doNotMoveCursor=1:AQID\u{0007}",
  )
}

pub fn iterm2_draw_at_saves_moves_and_restores_test() {
  iterm2.draw_at(Position(2, 5), <<1, 2, 3>>, Box(columns: 10, rows: 4))
  |> should.equal(
    esc
    <> "7"
    <> esc
    <> "[6;3H"
    <> iterm2.inline(<<1, 2, 3>>, Box(columns: 10, rows: 4))
    <> esc
    <> "8",
  )
}

pub fn iterm2_erase_blanks_each_row_of_the_box_test() {
  iterm2.erase(Position(2, 5), Box(columns: 3, rows: 2))
  |> should.equal(
    esc
    <> "7"
    <> esc
    <> "[0m"
    <> esc
    <> "[6;3H"
    <> esc
    <> "[3X"
    <> esc
    <> "[7;3H"
    <> esc
    <> "[3X"
    <> esc
    <> "8",
  )
}

// ─────────────────────────────────────────────────────────────────
// Fitting

pub fn a_small_image_keeps_its_natural_size_test() {
  graphics.fit(64, 40, CellSize(10, 20), Box(60, 12))
  |> should.equal(Box(columns: 7, rows: 2))
}

pub fn a_wide_image_is_limited_by_the_width_test() {
  graphics.fit(2000, 200, CellSize(10, 20), Box(60, 12))
  |> should.equal(Box(columns: 60, rows: 3))
}

pub fn a_tall_image_is_limited_by_the_height_test() {
  graphics.fit(1200, 700, CellSize(10, 20), Box(60, 12))
  |> should.equal(Box(columns: 42, rows: 12))
}

pub fn a_fitted_box_never_exceeds_the_limit_test() {
  list.each([1, 7, 99, 640, 1920, 5000], fn(w) {
    list.each([1, 3, 480, 1080, 9000], fn(h) {
      let box = graphics.fit(w, h, CellSize(8, 17), Box(60, 12))
      { box.columns >= 1 && box.columns <= 60 } |> should.be_true
      { box.rows >= 1 && box.rows <= 12 } |> should.be_true
    })
  })
}

pub fn malformed_sizes_ask_for_one_cell_test() {
  graphics.fit(0, 100, CellSize(10, 20), Box(60, 12))
  |> should.equal(Box(1, 1))
  graphics.fit(100, 100, CellSize(0, 20), Box(60, 12))
  |> should.equal(Box(1, 1))
  graphics.fit(100, 100, CellSize(10, 20), Box(0, 12))
  |> should.equal(Box(0, 0))
}

// The largest id is written in full, not cut to the 24 bits of a colour.
pub fn ids_print_in_decimal_test() {
  kitty.delete(id(0xFFFFFFFF))
  |> string.contains(int.to_string(0xFFFFFFFF))
  |> should.be_true
}

// The integers from `from` to `to`, both included.
fn inclusive(from: Int, to: Int) -> List(Int) {
  int.range(from: to, to: from - 1, with: [], run: fn(acc, i) { [i, ..acc] })
}
