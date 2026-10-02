//// `buffer.set_cells`: many single-column writes in one pass, keeping wide
//// graphemes whole at the edges of what was written.

import etui/buffer
import etui/geometry.{Position, rect_new}
import etui/style
import gleeunit/should

fn cell(symbol: String) -> buffer.Cell {
  buffer.Cell(
    content: buffer.Content(symbol: symbol, width: 1),
    style: style.default_style(),
    link: "",
  )
}

pub fn writes_land_where_they_are_aimed_test() {
  let buf =
    buffer.buffer_new(rect_new(0, 0, 3, 2))
    |> buffer.set_cells([
      #(Position(0, 0), cell("a")),
      #(Position(2, 1), cell("b")),
      #(Position(9, 9), cell("c")),
    ])
  buffer.cell_symbol(buffer.get_cell(buf, Position(0, 0))) |> should.equal("a")
  buffer.cell_symbol(buffer.get_cell(buf, Position(2, 1))) |> should.equal("b")
  buffer.get_cell(buf, Position(1, 0)) |> should.equal(buffer.empty_cell())
}

pub fn plain_writes_match_set_cell_in_a_loop_test() {
  let area = rect_new(0, 0, 4, 1)
  let looped =
    buffer.buffer_new(area)
    |> buffer.set_cell(Position(1, 0), cell("x"))
    |> buffer.set_cell(Position(2, 0), cell("y"))
  buffer.buffer_new(area)
  |> buffer.set_cells([
    #(Position(1, 0), cell("x")),
    #(Position(2, 0), cell("y")),
  ])
  |> buffer.diff(looped, _)
  |> should.equal([])
}

pub fn overwriting_a_continuation_blanks_its_wide_cell_test() {
  let buf =
    buffer.buffer_new(rect_new(0, 0, 4, 1))
    |> buffer.set_string(Position(0, 0), "你", style.default_style())
    |> buffer.set_cells([#(Position(1, 0), cell("x"))])
  buffer.get_cell(buf, Position(0, 0)) |> should.equal(buffer.empty_cell())
  buffer.cell_symbol(buffer.get_cell(buf, Position(1, 0))) |> should.equal("x")
}

pub fn overwriting_a_wide_cell_blanks_its_continuation_test() {
  let buf =
    buffer.buffer_new(rect_new(0, 0, 4, 1))
    |> buffer.set_string(Position(1, 0), "你", style.default_style())
    |> buffer.set_cells([#(Position(1, 0), cell("x"))])
  buffer.cell_symbol(buffer.get_cell(buf, Position(1, 0))) |> should.equal("x")
  buffer.get_cell(buf, Position(2, 0)) |> should.equal(buffer.empty_cell())
}
