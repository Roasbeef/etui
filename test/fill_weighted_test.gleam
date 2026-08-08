/// Weighted fill constraints.
import etui/geometry.{
  Fill, FillWeighted, Length, Max, Min, Percentage, resolve_sizes,
}
import gleam/list
import gleeunit/should

fn total(sizes: List(Int)) -> Int {
  list.fold(sizes, 0, fn(a, b) { a + b })
}

// ─────────────────────────────────────────────────────────────────
// Fill is FillWeighted(1)

pub fn weight_one_matches_plain_fill_test() {
  resolve_sizes(100, [FillWeighted(1), FillWeighted(1)])
  |> should.equal(resolve_sizes(100, [Fill, Fill]))
}

pub fn weighted_and_plain_fill_mix_test() {
  // Plain Fill counts as weight 1, so this is 1 : 3.
  resolve_sizes(100, [Fill, FillWeighted(3)])
  |> should.equal([25, 75])
}

// ─────────────────────────────────────────────────────────────────
// Proportions

pub fn two_to_one_test() {
  resolve_sizes(90, [FillWeighted(2), FillWeighted(1)])
  |> should.equal([60, 30])
}

pub fn one_to_two_test() {
  resolve_sizes(90, [FillWeighted(1), FillWeighted(2)])
  |> should.equal([30, 60])
}

pub fn weights_share_only_what_is_left_test() {
  // Length(10) and Percentage(20) go first, leaving 70 for the 3:4 split.
  let sizes =
    resolve_sizes(100, [
      Length(10),
      Percentage(20),
      FillWeighted(3),
      FillWeighted(4),
    ])
  sizes
  |> should.equal([10, 20, 30, 40])
  total(sizes)
  |> should.equal(100)
}

pub fn weights_are_scale_invariant_test() {
  resolve_sizes(100, [FillWeighted(2), FillWeighted(6)])
  |> should.equal(resolve_sizes(100, [FillWeighted(1), FillWeighted(3)]))
}

// ─────────────────────────────────────────────────────────────────
// Edges

pub fn zero_weight_claims_nothing_test() {
  resolve_sizes(100, [FillWeighted(0), FillWeighted(1)])
  |> should.equal([0, 100])
}

pub fn a_negative_weight_is_treated_as_zero_test() {
  resolve_sizes(100, [FillWeighted(-5), FillWeighted(1)])
  |> should.equal([0, 100])
}

pub fn all_weights_zero_leaves_the_space_unclaimed_test() {
  // Nothing wants the leftover, so nothing takes it, rather than dividing by
  // a zero total weight.
  resolve_sizes(100, [FillWeighted(0), FillWeighted(0)])
  |> should.equal([0, 0])
}

pub fn remainder_cells_go_to_the_earliest_fill_test() {
  // 10 does not divide by 3. The spare cell goes to the first, matching how
  // plain Fill has always rounded.
  resolve_sizes(10, [FillWeighted(1), FillWeighted(1), FillWeighted(1)])
  |> should.equal([4, 3, 3])
}

pub fn uneven_weights_still_fill_the_area_exactly_test() {
  let sizes =
    resolve_sizes(100, [FillWeighted(1), FillWeighted(1), FillWeighted(1)])
  total(sizes)
  |> should.equal(100)
}

// ─────────────────────────────────────────────────────────────────
// Interaction with the bounded constraints

pub fn bounds_are_satisfied_before_weights_split_the_rest_test() {
  // Max(20) caps at 20, leaving 80 for the 1:3 split.
  resolve_sizes(100, [Max(20), FillWeighted(1), FillWeighted(3)])
  |> should.equal([20, 20, 60])
}

pub fn weights_do_not_disturb_an_over_subscribed_minimum_test() {
  // The floors already exceed the budget, so the fills get nothing at all
  // rather than a negative share.
  let sizes = resolve_sizes(100, [Min(60), Min(60), FillWeighted(5)])
  total(sizes)
  |> should.equal(100)
  case sizes {
    [_, _, fill] -> fill |> should.equal(0)
    _ -> should.fail()
  }
}

// ─────────────────────────────────────────────────────────────────
// Counter-test: adding the variant must not move existing layouts

pub fn existing_fill_layouts_are_unchanged_test() {
  resolve_sizes(100, [Fill, Fill])
  |> should.equal([50, 50])
  resolve_sizes(10, [Fill, Fill, Fill])
  |> should.equal([4, 3, 3])
  resolve_sizes(100, [Length(30), Fill, Fill])
  |> should.equal([30, 35, 35])
  resolve_sizes(90, [Min(10), Max(20), Fill])
  |> should.equal([35, 20, 35])
  resolve_sizes(100, [Max(30), Fill])
  |> should.equal([30, 70])
}
