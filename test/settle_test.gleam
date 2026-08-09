/// Scroll offsets that persist between frames.
///
/// A list or table only knows how far to scroll once it knows how tall its
/// area is, and that is decided by the layout rather than the model. `settle`
/// is where the model gets told.
import etui/widgets/list as list_w
import etui/widgets/table
import gleeunit/should

fn select(state: list_w.ListState, index: Int) -> list_w.ListState {
  list_w.ListState(..state, selected: index)
}

// ─────────────────────────────────────────────────────────────────
// What settling buys

pub fn a_settled_viewport_holds_still_test() {
  // Ten rows visible. Step down to 15, which scrolls, then back up to 12,
  // which is still inside the window and must not move it.
  let scrolled = list_w.settle(select(list_w.state_new(), 15), 10)
  scrolled.offset
  |> should.equal(6)

  let back_up = list_w.settle(select(scrolled, 12), 10)
  back_up.offset
  |> should.equal(6)
}

pub fn an_unsettled_viewport_slides_with_every_step_test() {
  // The counter-test. Without keeping the offset it is recomputed from zero
  // each frame, so the selection is pinned to the last row and the window
  // moves under it on every step.
  let fresh = list_w.state_new()
  list_w.effective_offset(select(fresh, 15), 10)
  |> should.equal(6)
  list_w.effective_offset(select(fresh, 12), 10)
  |> should.equal(3)
}

pub fn scrolling_past_the_bottom_edge_moves_the_window_test() {
  let at_15 = list_w.settle(select(list_w.state_new(), 15), 10)
  // 16 is one past the window's last row, so the window follows by one.
  list_w.settle(select(at_15, 16), 10).offset
  |> should.equal(7)
}

pub fn scrolling_past_the_top_edge_moves_the_window_test() {
  let at_15 = list_w.settle(select(list_w.state_new(), 15), 10)
  // 5 is above the window, so the window jumps to put it at the top.
  list_w.settle(select(at_15, 5), 10).offset
  |> should.equal(5)
}

// ─────────────────────────────────────────────────────────────────
// Edges

pub fn a_selection_inside_the_first_page_needs_no_offset_test() {
  list_w.settle(select(list_w.state_new(), 3), 10).offset
  |> should.equal(0)
}

pub fn settling_is_idempotent_test() {
  let once = list_w.settle(select(list_w.state_new(), 15), 10)
  list_w.settle(once, 10)
  |> should.equal(once)
}

pub fn a_zero_height_area_leaves_the_offset_alone_test() {
  let state = list_w.settle(select(list_w.state_new(), 15), 10)
  list_w.settle(state, 0).offset
  |> should.equal(state.offset)
}

pub fn settling_never_touches_the_selection_test() {
  list_w.settle(select(list_w.state_new(), 15), 10).selected
  |> should.equal(15)
}

// ─────────────────────────────────────────────────────────────────
// Tables count their data rows, not their area rows

pub fn a_table_settles_on_its_data_height_test() {
  // The caller passes the data height, which is the area less the header row.
  let state = table.TableState(..table.state_new(), selected_row: 15)
  table.settle(state, 10).offset
  |> should.equal(6)
}

pub fn a_table_viewport_holds_still_too_test() {
  let state = table.TableState(..table.state_new(), selected_row: 15)
  let scrolled = table.settle(state, 10)
  table.settle(table.TableState(..scrolled, selected_row: 12), 10).offset
  |> should.equal(6)
}
