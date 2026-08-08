/// Pure layout mathematics. Zero dependencies. No terminal knowledge.
/// All functions are deterministic and testable without I/O.
import gleam/int
import gleam/list

/// Coordinate on the screen.
pub type Position {
  Position(x: Int, y: Int)
}

/// Dimensions in cells.
pub type Size {
  Size(width: Int, height: Int)
}

/// A rectangular area on screen.
pub type Rect {
  Rect(position: Position, size: Size)
}

/// How to split a rectangle when laying out widgets.
pub type Direction {
  /// Constraints stacked along X axis (side-by-side columns).
  Horizontal
  /// Constraints stacked along Y axis (rows).
  Vertical
}

/// Layout constraint: how much space to claim.
///
/// Priority (highest → lowest):
///   Length > Min/Max > Ratio/Percentage > Fill
pub type Constraint {
  /// Fixed cell count. Highest priority. Allocated first.
  Length(Int)
  /// At least n cells. Participates in flexible distribution with a floor.
  Min(Int)
  /// At most n cells. Participates in flexible distribution with a ceiling.
  Max(Int)
  /// Percentage of total (0..100). Computed cumulatively to avoid pixel loss.
  Percentage(Int)
  /// Rational fraction of total: numerator/denominator. Exact integer math.
  /// `Ratio(1, 3)` is one-third of the total space.
  Ratio(Int, Int)
  /// Flexible. Divides leftover equally after Length + Percentage + Ratio.
  Fill
  /// Flexible with a weight: takes `weight / sum_of_weights` of the leftover.
  /// `Fill` is `FillWeighted(1)`, so the two mix freely.
  ///
  /// ```gleam
  /// // Sidebar one third, content two thirds
  /// split_h(area, [FillWeighted(1), FillWeighted(2)])
  /// ```
  ///
  /// A weight of 0 claims nothing.
  FillWeighted(Int)
}

// ─────────────────────────────────────────────────────────────────
// Constructors

/// Create a Rect with clamped width/height to non-negative.
pub fn rect_new(x: Int, y: Int, width: Int, height: Int) -> Rect {
  Rect(
    position: Position(x: x, y: y),
    size: Size(width: int.max(0, width), height: int.max(0, height)),
  )
}

/// Zero-sized rect at origin.
pub fn rect_zero() -> Rect {
  Rect(position: Position(x: 0, y: 0), size: Size(width: 0, height: 0))
}

// ─────────────────────────────────────────────────────────────────
// Queries

/// X coordinate of the right edge (exclusive: x + width).
pub fn right(rect: Rect) -> Int {
  rect.position.x + rect.size.width
}

/// Y coordinate of the bottom edge (exclusive: y + height).
pub fn bottom(rect: Rect) -> Int {
  rect.position.y + rect.size.height
}

/// Area in cells.
pub fn area(rect: Rect) -> Int {
  rect.size.width * rect.size.height
}

/// Check if a position is inside the rect (inclusive of edges).
pub fn contains(rect: Rect, pos: Position) -> Bool {
  pos.x >= rect.position.x
  && pos.x < right(rect)
  && pos.y >= rect.position.y
  && pos.y < bottom(rect)
}

/// True if terminal cell `(x, y)` is inside `rect`.
/// Convenience wrapper over `contains` for use with mouse event coordinates.
pub fn hit_test(rect: Rect, x: Int, y: Int) -> Bool {
  contains(rect, Position(x: x, y: y))
}

/// Intersection of two rects. Returns the overlapping rect if any.
pub fn intersect(a: Rect, b: Rect) -> Result(Rect, Nil) {
  let left = int.max(a.position.x, b.position.x)
  let top = int.max(a.position.y, b.position.y)
  let right_edge = int.min(right(a), right(b))
  let bottom_edge = int.min(bottom(a), bottom(b))

  case left < right_edge && top < bottom_edge {
    True ->
      Ok(Rect(
        position: Position(x: left, y: top),
        size: Size(width: right_edge - left, height: bottom_edge - top),
      ))
    False -> Error(Nil)
  }
}

/// Union of two rects: smallest rect that contains both.
pub fn union(a: Rect, b: Rect) -> Rect {
  let left = int.min(a.position.x, b.position.x)
  let top = int.min(a.position.y, b.position.y)
  let right_edge = int.max(right(a), right(b))
  let bottom_edge = int.max(bottom(a), bottom(b))

  Rect(
    position: Position(x: left, y: top),
    size: Size(width: right_edge - left, height: bottom_edge - top),
  )
}

/// Padding removed from each side of a rect: `horizontal` from left and
/// right, `vertical` from top and bottom.
pub type Margin {
  Margin(horizontal: Int, vertical: Int)
}

/// Shrink a rect by `margin` on all four sides.
///
/// Matches ratatui's `Rect::inner`: the origin always moves in by the margin,
/// and the size saturates at zero when the rect is too small to hold it. The
/// result can therefore sit outside the original rect once it has collapsed,
/// which is the behaviour callers ported from ratatui expect.
///
/// ```gleam
/// geometry.inner(area, geometry.Margin(1, 1))  // one cell of padding
/// ```
pub fn inner(rect: Rect, margin: Margin) -> Rect {
  let h = int.max(0, margin.horizontal)
  let v = int.max(0, margin.vertical)
  Rect(
    position: Position(x: rect.position.x + h, y: rect.position.y + v),
    size: Size(
      width: int.max(0, rect.size.width - 2 * h),
      height: int.max(0, rect.size.height - 2 * v),
    ),
  )
}

/// Translate a rect by `dx`, `dy`. Size is unchanged.
pub fn offset(rect: Rect, dx: Int, dy: Int) -> Rect {
  Rect(
    position: Position(x: rect.position.x + dx, y: rect.position.y + dy),
    size: rect.size,
  )
}

/// Move and shrink `rect` so it fits entirely inside `bounds`.
/// Returns a zero-size rect when the two do not overlap at all.
pub fn clamp(rect: Rect, bounds: Rect) -> Rect {
  let w = int.min(rect.size.width, bounds.size.width)
  let h = int.min(rect.size.height, bounds.size.height)
  let x = int.clamp(rect.position.x, bounds.position.x, right(bounds) - w)
  let y = int.clamp(rect.position.y, bounds.position.y, bottom(bounds) - h)
  Rect(position: Position(x: x, y: y), size: Size(width: w, height: h))
}

/// The rect's size, dropping its position.
pub fn size(rect: Rect) -> Size {
  rect.size
}

/// One 1-cell-tall rect per row of `rect`, top to bottom.
pub fn rows(rect: Rect) -> List(Rect) {
  list.map(indices(rect.size.height), fn(i) {
    Rect(
      position: Position(x: rect.position.x, y: rect.position.y + i),
      size: Size(width: rect.size.width, height: 1),
    )
  })
}

/// One 1-cell-wide rect per column of `rect`, left to right.
pub fn columns(rect: Rect) -> List(Rect) {
  list.map(indices(rect.size.width), fn(i) {
    Rect(
      position: Position(x: rect.position.x + i, y: rect.position.y),
      size: Size(width: 1, height: rect.size.height),
    )
  })
}

// [0, 1, .., n-1]; empty for n <= 0.
fn indices(n: Int) -> List(Int) {
  indices_acc(n - 1, [])
}

fn indices_acc(i: Int, acc: List(Int)) -> List(Int) {
  case i < 0 {
    True -> acc
    False -> indices_acc(i - 1, [i, ..acc])
  }
}

// ─────────────────────────────────────────────────────────────────
// Core algorithm: resolve_sizes

/// Distribute total space among constraints.
///
/// Returns a list of sizes (one per constraint) that sum to ≤ total.
/// Sum equals total when Fill (or Min/Max) is present or constraints saturate.
///
/// Algorithm (three-phase Discrete Cumulative Allocation):
/// 1. Length, exact, allocated first. Clamped to remaining budget in order.
/// 2. Percentage + Ratio, proportional from total. Cumulative to prevent jitter.
///    Scaled proportionally if combined demand exceeds available budget.
/// 3. Fill, FillWeighted, Min and Max share the remainder by weight, bounded
///    by their floors and ceilings. When the bounds cannot all be met the
///    sizes are scaled to fit rather than over-allocated: the result always
///    fits the area it was asked to fill.
///
/// ## Stability under resize
///
/// With `Length`, `Percentage`, `Fill` and `FillWeighted`, growing the area by
/// a cell never moves a boundary backwards, so a resize does not make panels
/// jitter.
///
/// `Min`, `Max` and `Ratio` do not guarantee that. A slot pinned at its floor
/// competes in a smaller pool than a free one, so the size at which it stops
/// being pinned is a step rather than a slope and its neighbours resize
/// sharply across it. `Ratio` accumulates its fractions rather than rounding
/// each one separately, which removes the worst of its own jitter but not all
/// of it. Measured over 12000 random layouts the three together affect about
/// 0.2% of them, by a few cells.
///
/// If a layout is resized interactively and must not jitter, express it with
/// `Percentage` or `FillWeighted`.
pub fn resolve_sizes(total: Int, constraints: List(Constraint)) -> List(Int) {
  case total < 0 {
    True -> list.map(constraints, fn(_) { 0 })
    False -> resolve_sizes_impl(total, constraints)
  }
}

fn resolve_sizes_impl(total: Int, constraints: List(Constraint)) -> List(Int) {
  // Phase 1: Length (exact, highest priority)
  let #(length_sizes, length_used) = phase_length(constraints, total, 0, [])
  let prop_budget = int.max(0, total - length_used)

  // Phase 2: Percentage (old cumulative algorithm, preserves stability invariant)
  // Cumulative targets: floor(base * cumsum_pct / denom). Diffs give exact sizes.
  let pct_total_pct =
    list.fold(constraints, 0, fn(acc, c) {
      case c {
        Percentage(p) -> acc + p
        _ -> acc
      }
    })
  let #(denom, pct_base) = case total * pct_total_pct > prop_budget * 100 {
    True -> #(pct_total_pct, prop_budget)
    False -> #(100, total)
  }
  let #(pct_sizes, pct_used) =
    phase_percentage(constraints, denom, pct_base, 0, 0, [])

  // Phase 2b: Ratio. Each Ratio(a, b) desires total * a / b cells, computed
  // from a running fraction rather than one rounding per constraint, the same
  // way Percentage is computed above.
  let ratio_budget = int.max(0, prop_budget - pct_used)
  let ratio_demands = ratio_targets(constraints, total, 0, 1, 0, [])
  let total_ratio_demand = list.fold(ratio_demands, 0, fn(acc, d) { acc + d })
  let #(ratio_sizes, ratio_used) =
    phase_proportional(
      ratio_demands,
      ratio_budget,
      total_ratio_demand,
      0,
      0,
      [],
    )

  // Phase 3: Fill + Min + Max (flexible, divide remaining)
  let flex_budget = int.max(0, total - length_used - pct_used - ratio_used)
  let flex_sizes = phase_flex(constraints, flex_budget)

  assemble_sizes(
    constraints,
    length_sizes,
    pct_sizes,
    ratio_sizes,
    flex_sizes,
    [],
  )
}

fn phase_length(
  constraints: List(Constraint),
  total: Int,
  used: Int,
  acc: List(Int),
) -> #(List(Int), Int) {
  case constraints {
    [] -> #(list.reverse(acc), used)
    [c, ..rest] -> {
      let #(size, new_used) = case c {
        Length(v) -> {
          let take = int.min(v, int.max(0, total - used))
          #(take, used + take)
        }
        _ -> #(0, used)
      }
      phase_length(rest, total, new_used, [size, ..acc])
    }
  }
}

// Ratio demands, taken from a running sum of the fractions.
//
// Rounding each ratio on its own leaves the total short by a varying amount:
// two halves of 271 cells are 135 each and leave one cell over, while two
// halves of 272 are 136 each and leave none. Whatever else was in the layout
// then grew and shrank as the terminal was resized. Accumulating the fraction
// first and taking the difference between successive targets removes that:
// each ratio's target is non-decreasing in `total`, so the cells left for
// everyone else are too.
//
// `num`/`den` carry the running fraction, reduced each step so the numbers
// stay small enough to be exact on the JavaScript target as well.
fn ratio_targets(
  constraints: List(Constraint),
  total: Int,
  num: Int,
  den: Int,
  prev_target: Int,
  acc: List(Int),
) -> List(Int) {
  case constraints {
    [] -> list.reverse(acc)
    [Ratio(a, b), ..rest] ->
      case b == 0 || a <= 0 {
        True -> ratio_targets(rest, total, num, den, prev_target, [0, ..acc])
        False -> {
          let #(n, d) = reduce(num * b + a * den, den * b)
          let target = total * n / d
          ratio_targets(rest, total, n, d, target, [target - prev_target, ..acc])
        }
      }
    [_, ..rest] -> ratio_targets(rest, total, num, den, prev_target, [0, ..acc])
  }
}

fn reduce(n: Int, d: Int) -> #(Int, Int) {
  let g = gcd(int.absolute_value(n), int.absolute_value(d))
  case g {
    0 -> #(n, d)
    _ -> #(n / g, d / g)
  }
}

fn gcd(a: Int, b: Int) -> Int {
  case b {
    0 -> a
    _ -> gcd(b, a % b)
  }
}

// Old cumulative Percentage algorithm. Preserves the stability invariant:
// sum(pct_sizes) = floor(base * total_pct / denom). Rounding goes to last element.
fn phase_percentage(
  constraints: List(Constraint),
  denom: Int,
  base: Int,
  acc_pct: Int,
  prev_target: Int,
  acc: List(Int),
) -> #(List(Int), Int) {
  case constraints {
    [] -> #(list.reverse(acc), prev_target)
    [c, ..rest] -> {
      let #(size, new_acc, new_target) = case c {
        Percentage(p) -> {
          let new_acc_pct = acc_pct + p
          let target = case denom {
            0 -> 0
            _ -> base * new_acc_pct / denom
          }
          let s = target - prev_target
          #(s, new_acc_pct, target)
        }
        _ -> #(0, acc_pct, prev_target)
      }
      phase_percentage(rest, denom, base, new_acc, new_target, [size, ..acc])
    }
  }
}

// Cumulative proportional allocation. Prevents pixel-loss jitter.
// When total_demand <= budget: uses demands as-is (no scaling).
// When total_demand > budget: scales proportionally via cumulative targets.
fn phase_proportional(
  demands: List(Int),
  budget: Int,
  total_demand: Int,
  cumsum: Int,
  prev_target: Int,
  acc: List(Int),
) -> #(List(Int), Int) {
  case demands {
    [] -> #(list.reverse(acc), prev_target)
    [d, ..rest] -> {
      let new_cumsum = cumsum + d
      let target = case total_demand {
        0 -> 0
        _ ->
          case total_demand <= budget {
            True -> new_cumsum
            False -> budget * new_cumsum / total_demand
          }
      }
      let size = target - prev_target
      phase_proportional(rest, budget, total_demand, new_cumsum, target, [
        size,
        ..acc
      ])
    }
  }
}

// A flexible constraint reduced to what allocation needs: how much of the
// leftover it pulls, and the range it has to stay inside.
type Slot {
  /// Length, Percentage and Ratio: already sized, takes nothing here.
  Rigid
  Slot(weight: Int, lo: Int, hi: Int)
}

fn slot_of(c: Constraint, budget: Int) -> Slot {
  case c {
    Fill -> Slot(weight: 1, lo: 0, hi: budget)
    FillWeighted(w) -> Slot(weight: int.max(0, w), lo: 0, hi: budget)
    Min(n) -> Slot(weight: 1, lo: int.clamp(n, 0, budget), hi: budget)
    Max(n) -> Slot(weight: 1, lo: 0, hi: int.clamp(n, 0, budget))
    _ -> Rigid
  }
}

// Flexible allocation for Fill, FillWeighted, Min and Max.
//
// Every flexible slot takes a weight-proportional share of the leftover,
// bounded by its floor and ceiling. One pass cannot do that: clamping a slot
// to a bound changes how much is left for the others. So the budget is settled
// iteratively. Each round gives every still-open slot its share of what
// remains, freezes the ones whose share fell outside their bounds, and repeats
// with the smaller budget. A round that freezes nothing is the answer, and
// every other round freezes at least one slot, so it converges in at most one
// round per slot.
//
// The simpler version, giving every bounded slot `budget / count` and letting
// Fill absorb the rest, is not monotone: an integer-division floor jumps, the
// bounded slots snap to it, and the fill absorbs the discontinuity. Growing
// the area by one cell could then make an earlier panel one cell narrower.
// `[FillWeighted(4), Max(78), Percentage(21), Min(14)]` went from
// `[61, 59, 47, 59]` at 226 cells to `[60, 60, 47, 60]` at 227.
fn phase_flex(constraints: List(Constraint), budget: Int) -> List(Int) {
  let slots = list.map(constraints, slot_of(_, budget))
  let frozen =
    list.map(slots, fn(s) {
      case s {
        Rigid -> Ok(0)
        Slot(..) -> Error(Nil)
      }
    })
  fit_to_budget(settle(slots, frozen, budget, list.length(slots) + 1), budget)
}

// Floors are wishes, not guarantees. Freezing one slot at its minimum leaves
// less for the next, so a set of floors that looked affordable at the start
// can over-subscribe by the time the last slot is frozen:
// `[Min(17), Ratio(2, 4), Max(20), Min(49)]` on 166 settles to 169 cells.
//
// When that happens none of the floors can be honoured, so the sizes are
// scaled to the budget, which keeps equal constraints equal instead of
// over-allocating and letting build_rects truncate whoever came last.
fn fit_to_budget(sizes: List(Int), budget: Int) -> List(Int) {
  let total = list.fold(sizes, 0, fn(a, b) { a + b })
  case total > budget {
    False -> sizes
    True -> {
      let #(fitted, _) = phase_proportional(sizes, budget, total, 0, 0, [])
      fitted
    }
  }
}

fn settle(
  slots: List(Slot),
  frozen: List(Result(Int, Nil)),
  budget: Int,
  fuel: Int,
) -> List(Int) {
  let taken =
    list.fold(frozen, 0, fn(acc, f) {
      case f {
        Ok(n) -> acc + n
        Error(Nil) -> acc
      }
    })
  let remaining = int.max(0, budget - taken)
  let open_weight = open_weight_of(slots, frozen)
  case open_weight <= 0 || fuel <= 0 {
    True -> list.map(frozen, unwrap_size)
    False -> {
      let shares = open_shares(slots, frozen, remaining, open_weight)
      case clamp_round(slots, frozen, shares) {
        // Nothing fell outside its bounds, so this distribution stands.
        Error(Nil) -> merge_shares(frozen, shares)
        Ok(next) -> settle(slots, next, budget, fuel - 1)
      }
    }
  }
}

fn open_weight_of(slots: List(Slot), frozen: List(Result(Int, Nil))) -> Int {
  case slots, frozen {
    [Slot(weight: w, ..), ..s_rest], [Error(Nil), ..f_rest] ->
      w + open_weight_of(s_rest, f_rest)
    [_, ..s_rest], [_, ..f_rest] -> open_weight_of(s_rest, f_rest)
    _, _ -> 0
  }
}

// Weight-proportional split of `remaining` across the open slots. Frozen
// positions get 0. Division remainders go one each to the earliest open slots,
// so `[Fill, Fill, Fill]` on 10 is `[4, 3, 3]`.
fn open_shares(
  slots: List(Slot),
  frozen: List(Result(Int, Nil)),
  remaining: Int,
  total_weight: Int,
) -> List(Int) {
  let bases = base_shares(slots, frozen, remaining, total_weight, [])
  let claimed = list.fold(bases, 0, fn(a, b) { a + b })
  spread_remainder(slots, frozen, bases, remaining - claimed, [])
}

fn base_shares(
  slots: List(Slot),
  frozen: List(Result(Int, Nil)),
  remaining: Int,
  total_weight: Int,
  acc: List(Int),
) -> List(Int) {
  case slots, frozen {
    [Slot(weight: w, ..), ..s_rest], [Error(Nil), ..f_rest] ->
      base_shares(s_rest, f_rest, remaining, total_weight, [
        remaining * w / total_weight,
        ..acc
      ])
    [_, ..s_rest], [_, ..f_rest] ->
      base_shares(s_rest, f_rest, remaining, total_weight, [0, ..acc])
    _, _ -> list.reverse(acc)
  }
}

fn spread_remainder(
  slots: List(Slot),
  frozen: List(Result(Int, Nil)),
  bases: List(Int),
  extra: Int,
  acc: List(Int),
) -> List(Int) {
  case slots, frozen, bases {
    [Slot(weight: w, ..), ..s_rest], [Error(Nil), ..f_rest], [b, ..b_rest] ->
      case w > 0 && extra > 0 {
        True ->
          spread_remainder(s_rest, f_rest, b_rest, extra - 1, [b + 1, ..acc])
        False -> spread_remainder(s_rest, f_rest, b_rest, extra, [b, ..acc])
      }
    [_, ..s_rest], [_, ..f_rest], [b, ..b_rest] ->
      spread_remainder(s_rest, f_rest, b_rest, extra, [b, ..acc])
    _, _, _ -> list.reverse(acc)
  }
}

// Freeze every open slot whose share fell outside its bounds. `Error(Nil)`
// means nothing was out of bounds, so the round is final.
fn clamp_round(
  slots: List(Slot),
  frozen: List(Result(Int, Nil)),
  shares: List(Int),
) -> Result(List(Result(Int, Nil)), Nil) {
  let next = clamp_loop(slots, frozen, shares, [])
  case next == frozen {
    True -> Error(Nil)
    False -> Ok(next)
  }
}

fn clamp_loop(
  slots: List(Slot),
  frozen: List(Result(Int, Nil)),
  shares: List(Int),
  acc: List(Result(Int, Nil)),
) -> List(Result(Int, Nil)) {
  case slots, frozen, shares {
    [Slot(lo: lo, hi: hi, ..), ..s_rest], [Error(Nil), ..f_rest], [s, ..sh_rest]
    -> {
      let entry = case s < lo, s > hi {
        True, _ -> Ok(lo)
        _, True -> Ok(hi)
        _, _ -> Error(Nil)
      }
      clamp_loop(s_rest, f_rest, sh_rest, [entry, ..acc])
    }
    [_, ..s_rest], [f, ..f_rest], [_, ..sh_rest] ->
      clamp_loop(s_rest, f_rest, sh_rest, [f, ..acc])
    _, _, _ -> list.reverse(acc)
  }
}

fn merge_shares(
  frozen: List(Result(Int, Nil)),
  shares: List(Int),
) -> List(Int) {
  case frozen, shares {
    [Ok(n), ..f_rest], [_, ..s_rest] -> [n, ..merge_shares(f_rest, s_rest)]
    [Error(Nil), ..f_rest], [s, ..s_rest] -> [s, ..merge_shares(f_rest, s_rest)]
    _, _ -> []
  }
}

fn unwrap_size(f: Result(Int, Nil)) -> Int {
  case f {
    Ok(n) -> n
    Error(Nil) -> 0
  }
}

fn assemble_sizes(
  constraints: List(Constraint),
  length_sizes: List(Int),
  pct_sizes: List(Int),
  ratio_sizes: List(Int),
  flex_sizes: List(Int),
  acc: List(Int),
) -> List(Int) {
  case constraints {
    [] -> list.reverse(acc)
    [c, ..cs] -> {
      let size = pick_size(c, length_sizes, pct_sizes, ratio_sizes, flex_sizes)
      let ls = case length_sizes {
        [_, ..t] -> t
        _ -> []
      }
      let ps = case pct_sizes {
        [_, ..t] -> t
        _ -> []
      }
      let rs = case ratio_sizes {
        [_, ..t] -> t
        _ -> []
      }
      let fs = case flex_sizes {
        [_, ..t] -> t
        _ -> []
      }
      assemble_sizes(cs, ls, ps, rs, fs, [size, ..acc])
    }
  }
}

fn pick_size(
  constraint: Constraint,
  lengths: List(Int),
  pcts: List(Int),
  ratios: List(Int),
  flexes: List(Int),
) -> Int {
  case constraint {
    Length(_) ->
      case lengths {
        [h, ..] -> h
        _ -> 0
      }
    Percentage(_) ->
      case pcts {
        [h, ..] -> h
        _ -> 0
      }
    Ratio(_, _) ->
      case ratios {
        [h, ..] -> h
        _ -> 0
      }
    Fill | FillWeighted(_) | Min(_) | Max(_) ->
      case flexes {
        [h, ..] -> h
        _ -> 0
      }
  }
}

// ─────────────────────────────────────────────────────────────────
// Layout: split a rect by constraints

/// Split horizontally (columns side-by-side). Shorthand for `split(Horizontal, ...)`.
pub fn split_h(area: Rect, constraints: List(Constraint)) -> List(Rect) {
  split(Horizontal, area, constraints)
}

/// Split vertically (rows stacked). Shorthand for `split(Vertical, ...)`.
pub fn split_v(area: Rect, constraints: List(Constraint)) -> List(Rect) {
  split(Vertical, area, constraints)
}

/// Center a rect of `width × height` within `area`.
/// Clamps to area bounds. Common for popup placement.
///
/// ```gleam
/// let popup_area = geometry.centered_rect(60, 20, screen)
/// ```
pub fn centered_rect(width: Int, height: Int, area: Rect) -> Rect {
  let w = int.min(width, area.size.width)
  let h = int.min(height, area.size.height)
  let x = area.position.x + { area.size.width - w } / 2
  let y = area.position.y + { area.size.height - h } / 2
  Rect(position: Position(x: x, y: y), size: Size(width: w, height: h))
}

/// Center a rect sized as a percentage of `area` (`pct_w` and `pct_h` are 0–100).
/// Useful for responsive popup sizing:
///
/// ```gleam
/// let popup_area = geometry.percent_rect(60, 40, screen)  // 60% wide, 40% tall
/// ```
pub fn percent_rect(pct_w: Int, pct_h: Int, area: Rect) -> Rect {
  let w = area.size.width * int.clamp(pct_w, 0, 100) / 100
  let h = area.size.height * int.clamp(pct_h, 0, 100) / 100
  centered_rect(w, h, area)
}

/// Split a rect along a direction by applying constraints.
pub fn split(
  direction: Direction,
  area: Rect,
  constraints: List(Constraint),
) -> List(Rect) {
  split_with(direction, area, constraints, FlexStart, 0)
}

/// Split a rect with `spacing` cells of gap between each child.
/// Gap cells are taken from the total before distributing to constraints.
///
/// ```gleam
/// // Two columns with a 1-cell gap
/// split_with_spacing(Horizontal, area, [Fill, Fill], 1)
/// ```
pub fn split_with_spacing(
  direction: Direction,
  area: Rect,
  constraints: List(Constraint),
  spacing: Int,
) -> List(Rect) {
  split_with(direction, area, constraints, FlexStart, spacing)
}

// ─────────────────────────────────────────────────────────────────
// Flex layout

/// How leftover space is distributed once the children have been sized.
///
/// | Flex          | Where the leftover goes                                  |
/// |---------------|----------------------------------------------------------|
/// | `FlexStart`   | After the last child.                                    |
/// | `FlexEnd`     | Before the first child.                                  |
/// | `FlexCenter`  | Split between the two edges.                             |
/// | `FlexBetween` | Between children, nothing at the edges.                   |
/// | `FlexAround`  | Around each child: edges get half of an inner gap.        |
/// | `FlexEvenly`  | Equally between children and at both edges.               |
pub type Flex {
  FlexStart
  FlexEnd
  FlexCenter
  FlexBetween
  FlexAround
  FlexEvenly
}

/// Former name of `Flex`.
pub type FlexJustify =
  Flex

/// Split a rect with both a fixed gap between children and a rule for the
/// space nobody claimed. This is the general form; `split`, `split_h`,
/// `split_v`, `split_with_spacing` and `split_flex` are all this function with
/// some arguments filled in.
///
/// `spacing` is a gap that always sits between children and is taken out of
/// the budget before the constraints are resolved. `flex` then places whatever
/// the constraints did not claim. The two compose: `FlexBetween` with a
/// spacing of 2 keeps at least two cells between children and spreads the rest
/// on top of that.
///
/// ```gleam
/// // Toolbar: fixed buttons pushed to the edges, at least 1 cell apart
/// split_with(Horizontal, area, [Length(8), Length(8)], FlexBetween, 1)
///
/// // A 20-wide dialog centred in the area
/// split_with(Horizontal, area, [Length(20)], FlexCenter, 0)
/// ```
pub fn split_with(
  direction: Direction,
  area: Rect,
  constraints: List(Constraint),
  flex: Flex,
  spacing: Int,
) -> List(Rect) {
  let n = list.length(constraints)
  case n == 0 {
    True -> []
    False -> {
      let total = axis_length(direction, area)
      let gap = int.max(0, spacing)
      let gap_cells = gap * { n - 1 }
      let sizes = resolve_sizes(int.max(0, total - gap_cells), constraints)
      let claimed = list.fold(sizes, 0, fn(acc, s) { acc + s }) + gap_cells
      let leads = flex_leads(flex, n, int.max(0, total - claimed))
      build_flex_rects(direction, area, sizes, flex_offsets(sizes, leads, gap))
    }
  }
}

fn axis_length(direction: Direction, area: Rect) -> Int {
  case direction {
    Vertical -> area.size.height
    Horizontal -> area.size.width
  }
}

// Every flex mode is the same shape: n + 1 places where leftover space can go,
// one before each child and one after the last, each with a weight. Sharing
// the leftover out by those weights covers all six modes and keeps the
// arithmetic exact, so no cell is lost to rounding.
fn gap_weights(flex: Flex, n: Int) -> List(Int) {
  let inner = int.max(0, n - 1)
  case flex {
    FlexStart -> list.append(list.repeat(0, n), [1])
    FlexEnd -> [1, ..list.repeat(0, n)]
    FlexCenter -> [1, ..list.append(list.repeat(0, inner), [1])]
    FlexBetween -> [0, ..list.append(list.repeat(1, inner), [0])]
    // Edges carry half an inner gap, so inner gaps weigh twice as much.
    FlexAround -> [1, ..list.append(list.repeat(2, inner), [1])]
    FlexEvenly -> list.repeat(1, n + 1)
  }
}

// Leftover space to insert before each child, on top of the fixed gap.
fn flex_leads(flex: Flex, n: Int, leftover: Int) -> List(Int) {
  let weights = gap_weights(flex, n)
  let total = list.fold(weights, 0, fn(a, b) { a + b })
  case total <= 0 {
    True -> list.repeat(0, n)
    False -> {
      let bases = list.map(weights, fn(w) { leftover * w / total })
      let claimed = list.fold(bases, 0, fn(a, b) { a + b })
      // Take the first n: the last entry is the space after the last child,
      // which needs no offset of its own.
      spread_gap(weights, bases, leftover - claimed, [])
      |> list.take(n)
    }
  }
}

fn spread_gap(
  weights: List(Int),
  bases: List(Int),
  extra: Int,
  acc: List(Int),
) -> List(Int) {
  case weights, bases {
    [w, ..w_rest], [b, ..b_rest] ->
      case w > 0 && extra > 0 {
        True -> spread_gap(w_rest, b_rest, extra - 1, [b + 1, ..acc])
        False -> spread_gap(w_rest, b_rest, extra, [b, ..acc])
      }
    _, _ -> list.reverse(acc)
  }
}

fn flex_offsets(sizes: List(Int), leads: List(Int), gap: Int) -> List(Int) {
  offsets_loop(sizes, leads, gap, 0, [])
}

fn offsets_loop(
  sizes: List(Int),
  leads: List(Int),
  gap: Int,
  cursor: Int,
  acc: List(Int),
) -> List(Int) {
  case sizes, leads {
    [s, ..s_rest], [lead, ..l_rest] -> {
      let start = cursor + lead
      offsets_loop(s_rest, l_rest, gap, start + s + gap, [start, ..acc])
    }
    _, _ -> list.reverse(acc)
  }
}

fn build_flex_rects(
  direction: Direction,
  area: Rect,
  sizes: List(Int),
  offsets: List(Int),
) -> List(Rect) {
  rects_loop(direction, area, sizes, offsets, axis_length(direction, area), [])
}

fn rects_loop(
  direction: Direction,
  area: Rect,
  sizes: List(Int),
  offsets: List(Int),
  limit: Int,
  acc: List(Rect),
) -> List(Rect) {
  case sizes, offsets {
    [size, ..s_rest], [offset, ..o_rest] -> {
      // Clamp so no child can be reported as extending past its parent, even
      // if a caller hands us constraints the parent cannot hold.
      let start = int.clamp(offset, 0, limit)
      let clamped = int.min(size, limit - start)
      let rect = case direction {
        Vertical ->
          Rect(
            position: Position(x: area.position.x, y: area.position.y + start),
            size: Size(width: area.size.width, height: clamped),
          )
        Horizontal ->
          Rect(
            position: Position(x: area.position.x + start, y: area.position.y),
            size: Size(width: clamped, height: area.size.height),
          )
      }
      rects_loop(direction, area, s_rest, o_rest, limit, [rect, ..acc])
    }
    _, _ -> list.reverse(acc)
  }
}

/// Flex layout with a minimum gap between children.
///
/// Kept for the name; `split_with` is the same function with its arguments in
/// the order the rest of the module uses.
pub fn split_flex(
  direction: Direction,
  area: Rect,
  constraints: List(Constraint),
  justify: Flex,
  gap: Int,
) -> List(Rect) {
  split_with(direction, area, constraints, justify, gap)
}

// ─────────────────────────────────────────────────────────────────
// Responsive layout

/// A responsive breakpoint: applies `constraints` when `area` width >= `min_width`.
pub type Breakpoint {
  Breakpoint(min_width: Int, constraints: List(Constraint))
}

/// Split `area` horizontally using the first breakpoint whose `min_width` <=
/// `area.size.width`, evaluated in descending order. Falls back to the last
/// breakpoint (assumed smallest). Returns `[area]` if `breakpoints` is empty.
///
/// Example, two columns on wide screens, stacked on narrow:
/// ```gleam
/// geometry.split_responsive(area, [
///   geometry.Breakpoint(80, [Percentage(50), Percentage(50)]),
///   geometry.Breakpoint(0,  [Percentage(100)]),
/// ])
/// ```
pub fn split_responsive(
  area: Rect,
  breakpoints: List(Breakpoint),
) -> List(Rect) {
  case breakpoints {
    [] -> [area]
    _ -> {
      let sorted =
        list.sort(breakpoints, fn(a, b) {
          int.compare(b.min_width, a.min_width)
        })
      let chosen = pick_breakpoint(sorted, area.size.width)
      split_h(area, chosen)
    }
  }
}

fn pick_breakpoint(
  sorted_desc: List(Breakpoint),
  width: Int,
) -> List(Constraint) {
  case sorted_desc {
    [] -> []
    [bp] -> bp.constraints
    [bp, ..rest] ->
      case width >= bp.min_width {
        True -> bp.constraints
        False -> pick_breakpoint(rest, width)
      }
  }
}
