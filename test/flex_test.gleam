/// Flex layout: where the space nobody claimed ends up.
import etui/geometry.{
  type Rect, FlexAround, FlexBetween, FlexCenter, FlexEnd, FlexEvenly, FlexStart,
  Horizontal, Length, Vertical, rect_new, split, split_with, split_with_spacing,
}
import gleam/list
import gleeunit/should

fn area() -> Rect {
  rect_new(0, 0, 20, 1)
}

fn three() -> List(geometry.Constraint) {
  [Length(2), Length(2), Length(2)]
}

fn spans(rects: List(Rect)) -> List(#(Int, Int)) {
  list.map(rects, fn(r) { #(r.position.x, r.size.width) })
}

// Gaps between children plus the two edges, which is what each mode is really
// choosing between.
fn gaps(rects: List(Rect), width: Int) -> List(Int) {
  case rects {
    [] -> []
    _ -> {
      let #(rev, last_end) =
        list.fold(rects, #([], 0), fn(st, r) {
          let #(acc, cursor) = st
          #([r.position.x - cursor, ..acc], r.position.x + r.size.width)
        })
      list.reverse([width - last_end, ..rev])
    }
  }
}

// ─────────────────────────────────────────────────────────────────
// The six modes

pub fn start_packs_at_the_beginning_test() {
  spans(split_with(Horizontal, area(), three(), FlexStart, 0))
  |> should.equal([#(0, 2), #(2, 2), #(4, 2)])
}

pub fn end_packs_at_the_end_test() {
  spans(split_with(Horizontal, area(), three(), FlexEnd, 0))
  |> should.equal([#(14, 2), #(16, 2), #(18, 2)])
}

pub fn center_splits_the_leftover_between_the_edges_test() {
  spans(split_with(Horizontal, area(), three(), FlexCenter, 0))
  |> should.equal([#(7, 2), #(9, 2), #(11, 2)])
}

pub fn between_leaves_nothing_at_the_edges_test() {
  let rects = split_with(Horizontal, area(), three(), FlexBetween, 0)
  spans(rects)
  |> should.equal([#(0, 2), #(9, 2), #(18, 2)])
  gaps(rects, 20)
  |> should.equal([0, 7, 7, 0])
}

pub fn evenly_gives_the_edges_a_full_gap_test() {
  let rects = split_with(Horizontal, area(), three(), FlexEvenly, 0)
  gaps(rects, 20)
  |> should.equal([4, 4, 3, 3])
}

pub fn around_gives_the_edges_half_a_gap_test() {
  // Weights are 1 : 2 : 2 : 1, so the edges are about half an inner gap.
  let rects = split_with(Horizontal, area(), three(), FlexAround, 0)
  gaps(rects, 20)
  |> should.equal([3, 5, 4, 2])
}

// ─────────────────────────────────────────────────────────────────
// No cell is lost

pub fn every_mode_accounts_for_the_whole_area_test() {
  list.each(
    [FlexStart, FlexEnd, FlexCenter, FlexBetween, FlexAround, FlexEvenly],
    fn(flex) {
      let rects = split_with(Horizontal, area(), three(), flex, 0)
      let used = list.fold(rects, 0, fn(a, r) { a + r.size.width })
      let gap_total = list.fold(gaps(rects, 20), 0, fn(a, g) { a + g })
      used + gap_total
      |> should.equal(20)
    },
  )
}

pub fn an_odd_leftover_is_not_dropped_test() {
  // 20 cells, two children of 3: leftover 14 over three even gaps is 4, 5, 5
  // once the remainder is handed out rather than truncated away.
  let rects =
    split_with(
      Horizontal,
      rect_new(0, 0, 20, 1),
      [Length(3), Length(3)],
      FlexEvenly,
      0,
    )
  gaps(rects, 20)
  |> should.equal([5, 5, 4])
}

// ─────────────────────────────────────────────────────────────────
// Spacing composes with flex, which it did not before

pub fn spacing_is_a_floor_that_between_spreads_on_top_of_test() {
  // Two cells always between children, and the remaining ten shared out.
  let rects = split_with(Horizontal, area(), three(), FlexBetween, 2)
  gaps(rects, 20)
  |> should.equal([0, 7, 7, 0])
  spans(rects)
  |> should.equal([#(0, 2), #(9, 2), #(18, 2)])
}

pub fn spacing_still_applies_with_start_test() {
  spans(split_with(Horizontal, area(), three(), FlexStart, 3))
  |> should.equal([#(0, 2), #(5, 2), #(10, 2)])
}

pub fn spacing_never_pushes_a_child_out_of_the_area_test() {
  // Three children and a gap far wider than the area: children are clamped
  // rather than reported outside their parent.
  let rects =
    split_with(Horizontal, rect_new(0, 0, 6, 1), three(), FlexStart, 9)
  list.all(rects, fn(r) { r.position.x + r.size.width <= 6 })
  |> should.equal(True)
}

// ─────────────────────────────────────────────────────────────────
// Edges

pub fn a_single_child_centres_test() {
  spans(split_with(Horizontal, area(), [Length(4)], FlexCenter, 0))
  |> should.equal([#(8, 4)])
}

pub fn a_single_child_with_between_stays_at_the_start_test() {
  // There is no gap between one child and itself, so there is nowhere for the
  // leftover to go except after it.
  spans(split_with(Horizontal, area(), [Length(4)], FlexBetween, 0))
  |> should.equal([#(0, 4)])
}

pub fn no_constraints_yields_no_rects_test() {
  split_with(Horizontal, area(), [], FlexEvenly, 0)
  |> should.equal([])
}

pub fn a_zero_width_area_yields_zero_width_children_test() {
  split_with(Horizontal, rect_new(0, 0, 0, 1), three(), FlexEvenly, 0)
  |> list.all(fn(r) { r.size.width == 0 })
  |> should.equal(True)
}

// ─────────────────────────────────────────────────────────────────
// Counter-test: the plain helpers are the same function underneath

pub fn split_matches_flex_start_with_no_spacing_test() {
  split(Horizontal, area(), three())
  |> should.equal(split_with(Horizontal, area(), three(), FlexStart, 0))
}

pub fn split_with_spacing_matches_flex_start_test() {
  split_with_spacing(Vertical, rect_new(0, 0, 4, 30), three(), 2)
  |> should.equal(split_with(
    Vertical,
    rect_new(0, 0, 4, 30),
    three(),
    FlexStart,
    2,
  ))
}

pub fn vertical_and_horizontal_agree_on_the_axis_test() {
  let h = split_with(Horizontal, rect_new(0, 0, 20, 3), three(), FlexEvenly, 1)
  let v = split_with(Vertical, rect_new(0, 0, 3, 20), three(), FlexEvenly, 1)
  list.map(h, fn(r) { #(r.position.x, r.size.width) })
  |> should.equal(list.map(v, fn(r) { #(r.position.y, r.size.height) }))
}
