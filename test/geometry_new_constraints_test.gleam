/// Tests for new constraint types: Min, Max, Ratio.
/// Also tests split_with_spacing.
import etui/geometry.{
  Fill, Horizontal, Length, Max, Min, Percentage, Ratio, Vertical, rect_new,
  resolve_sizes, split, split_with_spacing,
}
import gleam/list
import gleeunit/should

// ─────────────────────────────────────────────────────────────────
// Ratio

pub fn ratio_one_third_test() {
  resolve_sizes(90, [Ratio(1, 3), Fill])
  |> should.equal([30, 60])
}

pub fn ratio_two_thirds_test() {
  resolve_sizes(90, [Ratio(2, 3), Fill])
  |> should.equal([60, 30])
}

pub fn ratio_half_half_test() {
  resolve_sizes(100, [Ratio(1, 2), Ratio(1, 2)])
  |> should.equal([50, 50])
}

pub fn ratio_with_length_test() {
  // Length(10) fixed, Ratio(1,2) of total=100 = 50, Fill gets 40
  resolve_sizes(100, [Length(10), Ratio(1, 2), Fill])
  |> should.equal([10, 50, 40])
}

pub fn ratio_zero_denominator_is_zero_test() {
  resolve_sizes(100, [Ratio(1, 0), Fill])
  |> should.equal([0, 100])
}

pub fn ratio_overflow_scales_test() {
  // Two Ratio(3,4) each want 75 from 100, total demand=150 > 100
  // Scales: each gets 50
  resolve_sizes(100, [Ratio(3, 4), Ratio(3, 4)])
  |> should.equal([50, 50])
}

// ─────────────────────────────────────────────────────────────────
// Min

pub fn min_gets_base_share_test() {
  // Two Min(20), flex_budget=100, base=50 ≥ 20, so both get 50
  resolve_sizes(100, [Min(20), Min(20)])
  |> should.equal([50, 50])
}

pub fn min_floor_is_capped_by_the_remaining_budget_test() {
  // Length(80) leaves 20 cells. Min(30) cannot have its floor, and handing it
  // 30 anyway produced 110 cells of sizes for a 100-cell area; build_rects
  // then truncated the overflow, so the reported size was a lie.
  resolve_sizes(100, [Length(80), Min(30)])
  |> should.equal([80, 20])
}

pub fn equal_minimums_that_do_not_fit_stay_equal_test() {
  // Both ask for 60 of a 100-cell budget. Neither can have it, so they share.
  // Previously this resolved to [60, 60] and the second was truncated to 40.
  resolve_sizes(100, [Min(60), Min(60)])
  |> should.equal([50, 50])
}

pub fn unequal_minimums_that_do_not_fit_scale_in_proportion_test() {
  // Base share is 50, so Min(60) wants 60 and Min(30) wants 50: 110 in total.
  // Scaled back to 100 they keep their ratio and still fill the area exactly.
  let sizes = resolve_sizes(100, [Min(60), Min(30)])
  sizes
  |> should.equal([54, 46])
  list.fold(sizes, 0, fn(a, b) { a + b })
  |> should.equal(100)
}

pub fn a_minimum_that_fits_is_still_honoured_test() {
  resolve_sizes(100, [Min(60), Fill])
  |> should.equal([60, 40])
}

pub fn min_with_fill_test() {
  // flex_budget=80 among Min(10) and Fill. base=40. Min gets max(10,40)=40. Fill gets 40.
  resolve_sizes(100, [Length(20), Min(10), Fill])
  |> should.equal([20, 40, 40])
}

pub fn min_zero_acts_like_fill_test() {
  resolve_sizes(100, [Min(0), Min(0)])
  |> should.equal([50, 50])
}

// ─────────────────────────────────────────────────────────────────
// Max

pub fn max_caps_at_ceiling_test() {
  // flex_budget=100, 2 flex slots, base=50. Max(30)→30. Fill gets remainder: 100-30=70.
  resolve_sizes(100, [Max(30), Fill])
  |> should.equal([30, 70])
}

pub fn max_large_ceiling_acts_like_fill_test() {
  // Max(200) — ceiling above base=50, acts like Fill
  resolve_sizes(100, [Max(200), Max(200)])
  |> should.equal([50, 50])
}

pub fn max_with_length_test() {
  // flex_budget=60, 2 flex slots, base=30. Max(20)→20. Fill gets 60-20=40.
  resolve_sizes(100, [Length(40), Max(20), Fill])
  |> should.equal([40, 20, 40])
}

pub fn max_zero_gets_zero_test() {
  // flex_budget=100, 2 flex slots, base=50. Max(0)→0. Fill gets 100-0=100.
  resolve_sizes(100, [Max(0), Fill])
  |> should.equal([0, 100])
}

// ─────────────────────────────────────────────────────────────────
// Mixed new constraints

pub fn min_max_fill_together_test() {
  // flex_budget=90, 3 flex slots, base=30. Min(10)→30, Max(20)→20. Fill gets 90-30-20=40.
  resolve_sizes(90, [Min(10), Max(20), Fill])
  |> should.equal([30, 20, 40])
}

pub fn ratio_and_fill_test() {
  resolve_sizes(120, [Ratio(1, 4), Fill])
  |> should.equal([30, 90])
}

pub fn all_six_constraints_test() {
  // Length(10), Percentage(20)→20, Ratio(1,4)→25
  // flex_budget=45, 3 flex slots, base=15
  // Min(5)→15, Max(10)→10. Fill gets 45-15-10=20.
  resolve_sizes(100, [
    Length(10),
    Percentage(20),
    Ratio(1, 4),
    Min(5),
    Max(10),
    Fill,
  ])
  |> should.equal([10, 20, 25, 15, 10, 20])
}

// ─────────────────────────────────────────────────────────────────
// split_with_spacing

pub fn spacing_two_cols_test() {
  let area = rect_new(0, 0, 101, 1)
  let cols = split_with_spacing(Horizontal, area, [Fill, Fill], 1)
  case cols {
    [a, b] -> {
      a.size.width |> should.equal(50)
      b.size.width |> should.equal(50)
      a.position.x |> should.equal(0)
      b.position.x |> should.equal(51)
    }
    _ -> should.fail()
  }
}

pub fn spacing_three_rows_test() {
  let area = rect_new(0, 0, 1, 32)
  let rows = split_with_spacing(Vertical, area, [Fill, Fill, Fill], 2)
  case rows {
    [a, b, c] -> {
      // Total gaps = 2*2=4, available=28, 3 fills: 10+9+9=28
      a.size.height |> should.equal(10)
      b.size.height |> should.equal(9)
      c.size.height |> should.equal(9)
      a.position.y |> should.equal(0)
      b.position.y |> should.equal(12)
      c.position.y |> should.equal(23)
    }
    _ -> should.fail()
  }
}

pub fn spacing_zero_same_as_split_test() {
  let area = rect_new(0, 0, 100, 10)
  let with_space = split_with_spacing(Horizontal, area, [Fill, Fill], 0)
  let without = split(Horizontal, area, [Fill, Fill])
  with_space |> should.equal(without)
}

pub fn spacing_single_constraint_no_gap_test() {
  let area = rect_new(0, 0, 100, 10)
  let r = split_with_spacing(Horizontal, area, [Fill], 5)
  r |> should.equal([area])
}
