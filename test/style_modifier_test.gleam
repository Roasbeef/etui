/// Styles that can take a modifier away, not only add one.
import etui/style
import gleam/list
import gleeunit/should

fn has(s: style.Style, m: style.Modifier) -> Bool {
  style.has(s.modifier, m)
}

// ─────────────────────────────────────────────────────────────────
// The gap this closes

pub fn an_overlay_can_clear_a_modifier_the_base_had_set_test() {
  // A theme sets bold everywhere; one widget must not be bold. With only an
  // additive modifier this was impossible to express, because an empty
  // modifier in the overlay means "change nothing".
  let theme = style.default_style() |> style.add_modifier(style.bold())
  let quiet = style.default_style() |> style.remove_modifier(style.bold())
  style.patch(theme, quiet)
  |> has(style.bold())
  |> should.equal(False)
}

pub fn an_empty_overlay_still_changes_nothing_test() {
  let theme = style.default_style() |> style.add_modifier(style.bold())
  style.patch(theme, style.default_style())
  |> has(style.bold())
  |> should.equal(True)
}

pub fn an_overlay_only_clears_what_it_names_test() {
  let base =
    style.default_style()
    |> style.add_modifier(style.bold())
    |> style.add_modifier(style.italic())
  let overlay = style.default_style() |> style.remove_modifier(style.bold())
  let out = style.patch(base, overlay)
  has(out, style.bold())
  |> should.equal(False)
  has(out, style.italic())
  |> should.equal(True)
}

// ─────────────────────────────────────────────────────────────────
// add and remove stay consistent with each other

pub fn adding_cancels_a_pending_removal_test() {
  let s =
    style.default_style()
    |> style.remove_modifier(style.bold())
    |> style.add_modifier(style.bold())
  has(s, style.bold())
  |> should.equal(True)
  style.has(s.sub_modifier, style.bold())
  |> should.equal(False)
}

pub fn removing_cancels_a_pending_addition_test() {
  let s =
    style.default_style()
    |> style.add_modifier(style.bold())
    |> style.remove_modifier(style.bold())
  has(s, style.bold())
  |> should.equal(False)
  style.has(s.sub_modifier, style.bold())
  |> should.equal(True)
}

pub fn patching_is_associative_over_three_layers_test() {
  let a = style.default_style() |> style.add_modifier(style.bold())
  let b = style.default_style() |> style.remove_modifier(style.bold())
  let c = style.default_style() |> style.add_modifier(style.italic())
  style.patch(style.patch(a, b), c)
  |> should.equal(style.patch(a, style.patch(b, c)))
}

// ─────────────────────────────────────────────────────────────────
// Colours are unchanged

pub fn default_colours_fall_through_test() {
  let base =
    style.default_style()
    |> style.with_fg(style.Indexed(1))
    |> style.with_bg(style.Indexed(2))
  let out = style.patch(base, style.default_style())
  out.fg
  |> should.equal(style.Indexed(1))
  out.bg
  |> should.equal(style.Indexed(2))
}

pub fn an_explicit_colour_wins_test() {
  let base = style.default_style() |> style.with_fg(style.Indexed(1))
  let over = style.default_style() |> style.with_fg(style.Indexed(9))
  style.patch(base, over).fg
  |> should.equal(style.Indexed(9))
}

// ─────────────────────────────────────────────────────────────────
// New modifier bits reach the terminal

pub fn hidden_emits_sgr_8_test() {
  style.ansi_modifier(style.hidden())
  |> should.equal("\u{001B}[8m")
}

pub fn rapid_blink_emits_sgr_6_test() {
  style.ansi_modifier(style.rapid_blink())
  |> should.equal("\u{001B}[6m")
}

pub fn the_new_bits_do_not_collide_with_the_old_ones_test() {
  let all =
    style.none()
    |> style.add(style.bold())
    |> style.add(style.dim())
    |> style.add(style.italic())
    |> style.add(style.underline())
    |> style.add(style.blink())
    |> style.add(style.reverse())
    |> style.add(style.strikethrough())
    |> style.add(style.hidden())
    |> style.add(style.rapid_blink())
  // With every bit set, each one is still individually readable and each SGR
  // code appears exactly once in the sequence.
  list.each(
    [
      style.bold(),
      style.dim(),
      style.italic(),
      style.underline(),
      style.blink(),
      style.reverse(),
      style.strikethrough(),
      style.hidden(),
      style.rapid_blink(),
    ],
    fn(bit) {
      style.has(all, bit)
      |> should.equal(True)
    },
  )
  style.ansi_modifier(all)
  |> should.equal("\u{001B}[6;8;9;7;5;4;3;2;1m")
}

pub fn removing_one_bit_leaves_the_others_test() {
  let all =
    style.none()
    |> style.add(style.bold())
    |> style.add(style.hidden())
    |> style.add(style.rapid_blink())
    |> style.remove(style.hidden())
  style.has(all, style.hidden())
  |> should.equal(False)
  style.has(all, style.rapid_blink())
  |> should.equal(True)
  style.has(all, style.bold())
  |> should.equal(True)
}
