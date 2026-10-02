//// The graphics probe's reply parser, and the input parser's handling of
//// replies that arrive late. Pure: no terminal is involved, so every case is
//// a byte string a terminal could send.

import etui/graphics.{
  CellSize, ColourDisabled, InsideHerdr, Iterm2, Kitty, Skip, Supported,
  TextOnly, Unsupported,
}
import etui/graphics/probe
import etui/graphics/reply
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import gleeunit/should

const esc = "\u{001B}"

fn kitty_ok() -> String {
  esc <> "_Gi=31;OK" <> esc <> "\\"
}

fn da1() -> String {
  esc <> "[?62;22;52c"
}

fn xtversion(name: String) -> String {
  esc <> "P>|" <> name <> esc <> "\\"
}

fn cell_pixels(w: Int, h: Int) -> String {
  esc <> "[6;" <> int.to_string(h) <> ";" <> int.to_string(w) <> "t"
}

fn window_pixels(w: Int, h: Int) -> String {
  esc <> "[4;" <> int.to_string(h) <> ";" <> int.to_string(w) <> "t"
}

fn window_cells(c: Int, r: Int) -> String {
  esc <> "[8;" <> int.to_string(r) <> ";" <> int.to_string(c) <> "t"
}

// What kitty sends back for `probe.query()`.
fn kitty_answer() -> String {
  kitty_ok()
  <> xtversion("kitty(0.39.1)")
  <> cell_pixels(10, 21)
  <> window_pixels(800, 630)
  <> window_cells(80, 30)
  <> da1()
}

fn probed(chunks: List(String)) -> probe.Probe {
  list.fold(chunks, probe.new(), probe.feed)
}

fn caps(chunks: List(String)) -> graphics.Capabilities {
  probe.capabilities(probed(chunks))
}

// ─────────────────────────────────────────────────────────────────
// The query

pub fn query_ends_with_the_da1_sentinel_test() {
  let q = probe.query()
  string.ends_with(q, esc <> "[c") |> should.be_true
  string.starts_with(
    q,
    esc <> "_Gi=31,s=1,v=1,a=q,t=d,f=24;AAAA" <> esc <> "\\",
  )
  |> should.be_true
}

// ─────────────────────────────────────────────────────────────────
// Each reply alone

pub fn kitty_ok_reply_is_recognised_test() {
  reply.recognise(string.to_graphemes(string.drop_start(kitty_ok(), 1)))
  |> should.equal(reply.Recognised(reply.KittyGraphics(31, "OK"), []))
}

pub fn da1_reply_is_recognised_test() {
  reply.recognise(string.to_graphemes("[?62;22;52c"))
  |> should.equal(reply.Recognised(reply.PrimaryAttributes([62, 22, 52]), []))
}

pub fn xtversion_reply_is_recognised_test() {
  reply.recognise(string.to_graphemes("P>|iTerm2 3.5.0" <> esc <> "\\x"))
  |> should.equal(
    reply.Recognised(reply.TerminalVersion("iTerm2 3.5.0"), ["x"]),
  )
}

pub fn window_reports_are_recognised_test() {
  reply.recognise(string.to_graphemes("[6;21;10t"))
  |> should.equal(reply.Recognised(reply.CellPixels(width: 10, height: 21), []))
  reply.recognise(string.to_graphemes("[4;630;800t"))
  |> should.equal(
    reply.Recognised(reply.WindowPixels(width: 800, height: 630), []),
  )
  reply.recognise(string.to_graphemes("[8;30;80t"))
  |> should.equal(
    reply.Recognised(reply.WindowCells(columns: 80, rows: 30), []),
  )
}

pub fn a_key_sequence_is_not_a_reply_test() {
  reply.recognise(string.to_graphemes("[A")) |> should.equal(reply.NotAReply)
  reply.recognise(string.to_graphemes("[<35;10;5M"))
  |> should.equal(reply.NotAReply)
  reply.recognise(["x"]) |> should.equal(reply.NotAReply)
}

pub fn a_lone_alt_underscore_is_not_a_reply_test() {
  reply.recognise(["_"]) |> should.equal(reply.NotAReply)
  reply.could_begin(["_"]) |> should.be_true
  reply.could_begin(["_", "x"]) |> should.be_false
}

// ─────────────────────────────────────────────────────────────────
// Whole answers

pub fn kitty_answer_is_kitty_with_a_cell_size_test() {
  let c = caps([kitty_answer()])
  c.kitty |> should.equal(Supported)
  c.iterm2 |> should.equal(Unsupported)
  c.cell_size |> should.equal(Some(CellSize(width: 10, height: 21)))
  c.terminal |> should.equal(Some("kitty(0.39.1)"))
  graphics.protocol(c) |> should.equal(Kitty)
  probe.status(probed([kitty_answer()])) |> should.equal(probe.Answered)
}

pub fn iterm2_answer_is_iterm2_test() {
  let c = caps([xtversion("iTerm2 3.5.4") <> cell_pixels(14, 28) <> da1()])
  c.kitty |> should.equal(Unsupported)
  c.iterm2 |> should.equal(Supported)
  graphics.protocol(c) |> should.equal(Iterm2)
}

pub fn a_da1_only_answer_supports_nothing_test() {
  let p = probed([da1()])
  probe.status(p) |> should.equal(probe.Answered)
  probe.capabilities(p) |> should.equal(graphics.none())
  graphics.protocol(probe.capabilities(p)) |> should.equal(TextOnly)
}

pub fn no_answer_at_all_supports_nothing_and_keeps_waiting_test() {
  let p = probed([])
  probe.status(p) |> should.equal(probe.Waiting)
  probe.capabilities(p) |> should.equal(graphics.none())
}

pub fn a_kitty_error_is_not_support_test() {
  let c = caps([esc <> "_Gi=31;EINVAL:bad pixel" <> esc <> "\\" <> da1()])
  c.kitty |> should.equal(Unsupported)
}

pub fn a_kitty_ok_for_another_id_is_not_support_test() {
  let c = caps([esc <> "_Gi=7;OK" <> esc <> "\\" <> da1()])
  c.kitty |> should.equal(Unsupported)
}

pub fn a_reply_after_da1_does_not_count_test() {
  let c = caps([da1() <> kitty_ok() <> xtversion("iTerm2 3.5")])
  c |> should.equal(graphics.none())
}

pub fn another_terminal_named_in_xtversion_is_not_iterm2_test() {
  let c = caps([xtversion("WezTerm 20240203") <> da1()])
  c.iterm2 |> should.equal(Unsupported)
  c.terminal |> should.equal(Some("WezTerm 20240203"))
}

pub fn cell_size_falls_back_to_window_over_cells_test() {
  caps([window_pixels(800, 600) <> window_cells(80, 30) <> da1()]).cell_size
  |> should.equal(Some(CellSize(width: 10, height: 20)))
}

pub fn a_zero_cell_report_is_no_answer_test() {
  caps([cell_pixels(0, 0) <> da1()]).cell_size |> should.equal(None)
  caps([window_pixels(0, 0) <> window_cells(80, 30) <> da1()]).cell_size
  |> should.equal(None)
}

// ─────────────────────────────────────────────────────────────────
// Interleaving, splitting and garbage

pub fn keys_typed_during_the_probe_are_kept_apart_test() {
  let p =
    probed([
      "ab" <> kitty_ok() <> "c" <> esc <> "[A" <> xtversion("kitty") <> "d",
      da1() <> "e",
    ])
  probe.capabilities(p).kitty |> should.equal(Supported)
  probe.typed(p) |> should.equal("abc" <> esc <> "[Ade")
}

pub fn every_split_of_the_answer_gives_the_same_result_test() {
  let whole = "x" <> kitty_answer() <> "y"
  let gs = string.to_graphemes(whole)
  let expected = caps([whole])
  inclusive(0, list.length(gs))
  |> list.each(fn(at) {
    let #(first, second) = list.split(gs, at)
    let p = probed([string.concat(first), string.concat(second)])
    probe.capabilities(p) |> should.equal(expected)
    probe.typed(p) |> should.equal("xy")
    probe.status(p) |> should.equal(probe.Answered)
  })
}

pub fn a_reply_one_grapheme_per_read_still_parses_test() {
  let p = probed(string.to_graphemes(kitty_answer()))
  probe.capabilities(p) |> should.equal(caps([kitty_answer()]))
}

pub fn an_unterminated_reply_cut_by_a_new_escape_is_malformed_test() {
  // ESC _ G with no ST, then a real DA1: the string ends at the next ESC,
  // and the DA1 behind it still counts as the end of the answer.
  let p = probed([esc <> "_Gi=31;OK" <> da1()])
  probe.status(p) |> should.equal(probe.Answered)
  probe.capabilities(p).kitty |> should.equal(Unsupported)
  probe.replies(p)
  |> should.equal([
    reply.Malformed("i=31;OK"),
    reply.PrimaryAttributes([62, 22, 52]),
  ])
}

pub fn garbage_never_crashes_and_never_counts_test() {
  let inputs = [
    esc <> "_G" <> esc <> "\\",
    esc <> "_Gnonsense" <> esc <> "\\",
    esc <> "_Gi=abc;OK" <> esc <> "\\",
    esc <> "[6;x;yt",
    esc <> "[9;1;2t",
    esc <> "[?c",
    esc <> esc <> esc,
    "\u{0000}\u{00FF}\u{10FFFF}",
    esc <> "P>|" <> esc <> "x",
  ]
  list.each(inputs, fn(input) {
    let c = caps([input <> da1()])
    c.kitty |> should.equal(Unsupported)
    c.iterm2 |> should.equal(Unsupported)
    c.cell_size |> should.equal(None)
  })
}

// ─────────────────────────────────────────────────────────────────
// Whether to ask

fn env(pairs: List(#(String, String))) -> fn(String) -> Result(String, Nil) {
  fn(name) { list.key_find(pairs, name) }
}

pub fn decide_skips_inside_herdr_and_under_no_color_test() {
  graphics.decide(env([])) |> should.equal(graphics.Probe)
  graphics.decide(env([#("HERDR_ENV", "1")])) |> should.equal(Skip(InsideHerdr))
  graphics.decide(env([#("NO_COLOR", "1")]))
  |> should.equal(Skip(ColourDisabled))

  // no-color.org: an empty NO_COLOR is not a request.
  graphics.decide(env([#("NO_COLOR", "")])) |> should.equal(graphics.Probe)

  // tmux is asked; its own answers make the result "no".
  graphics.decide(env([#("TMUX", "/tmp/tmux-501/default,1,0")]))
  |> should.equal(graphics.Probe)
}

// The integers from `from` to `to`, both included.
fn inclusive(from: Int, to: Int) -> List(Int) {
  int.range(from: to, to: from - 1, with: [], run: fn(acc, i) { [i, ..acc] })
}
