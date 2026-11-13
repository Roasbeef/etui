// Cell width of strings that mix printable ASCII with everything else.
//
// `text.cell_width` measures printable ASCII a byte at a time and sends only
// the stretches around non-ASCII text through grapheme segmentation. The
// reference below is the definition it must agree with: segment the whole
// string and add up the width of each cluster. The strings are generated from
// fragments chosen to land on every boundary the fast path cuts at: an ASCII
// base followed by a combining mark, a variation selector or a joiner, a
// prepended mark before ASCII, controls beside clusters, and runs of regional
// indicators.

import etui/text
import gleam/int
import gleam/list
import gleam/string
import gleeunit/should

fn reference_width(s: String) -> Int {
  s
  |> string.to_graphemes
  |> list.fold(0, fn(acc, g) { acc + text.grapheme_cell_width(g) })
}

fn lcg(seed: Int) -> Int {
  { seed * 1_664_525 + 1_013_904_223 } % 2_147_483_647
}

const fragments = [
  "a", "b", "Z", "0", "#", "*", " ", "~", "word", "abcd", "abcdefgh", "\n", "\r",
  "\r\n", "\t", "\u{7F}", "\u{0301}", "\u{0308}", "\u{FE0E}", "\u{FE0F}",
  "\u{200D}", "\u{200C}", "\u{20E3}", "\u{0600}", "\u{1100}", "\u{1161}",
  "\u{11A8}", "✓", "●", "·", "›", "—", "─", "☺", "✦", "⚡", "✅", "漢", "字", "カ",
  "ひ", "한", "각", "ü", "α", "я", "ß", "\u{00AD}", "\u{0085}", "\u{2028}",
  "\u{3099}", "\u{0483}", "\u{1F3FD}", "🚀", "👨", "👩", "👧", "🏽", "🇯", "🇵", "🇺",
  "é", "e\u{0301}", "❤\u{FE0F}", "☺\u{FE0E}", "1\u{FE0F}\u{20E3}",
  "👨\u{200D}👩\u{200D}👧",
]

fn pick(seed: Int, from: List(String), count: Int) -> #(String, Int) {
  let length = list.length(from)
  build(seed, from, length, count, "")
}

fn build(
  seed: Int,
  from: List(String),
  length: Int,
  count: Int,
  acc: String,
) -> #(String, Int) {
  case count <= 0 {
    True -> #(acc, seed)
    False -> {
      let next = lcg(seed)
      let assert Ok(fragment) = list.drop(from, next / 7 % length) |> list.first
      build(next, from, length, count - 1, acc <> fragment)
    }
  }
}

fn check(seed: Int, runs: Int) -> Nil {
  case runs <= 0 {
    True -> Nil
    False -> {
      let #(s, next) = pick(seed, fragments, 1 + seed % 17)
      case text.cell_width(s) == reference_width(s) {
        True -> check(lcg(next), runs - 1)
        False -> {
          let _ = should.equal(text.cell_width(s), reference_width(s))
          Nil
        }
      }
    }
  }
}

// Fifty thousand generated strings of one to seventeen fragments.
pub fn mixed_width_matches_grapheme_reference_test() {
  check(12_345, 50_000)
}

// The boundary cases by hand, each of which the generator can miss.
pub fn mixed_width_boundaries_test() {
  [
    "a\u{FE0F}", "a\u{FE0F}b", "ab\u{0301}", "ab\u{0301}cd", "x\u{200D}y",
    "\u{0600}a", "\u{0600}ab", "a\u{0600}b", "a✓b", "a✓", "✓a", "✓✓✓", "a✓b✓c",
    "abcd✓efgh", "abcdefgh漢efgh", "abcd\n\u{0301}", "\n\u{FE0F}x", "\r\n✓",
    "ok ✓ done", "✓\u{0301}", "漢\u{FE0F}x", "ñ\u{0301}z", "ひ\u{3099}", "각ᆨ", "ᄀ각",
    "🚀\u{1F3FD}a", "🚀\u{200D}🚀", "\u{0600}✓", "🇯🇵🇺🇸a", "a🇯🇵", "👨\u{200D}👩a",
    "a👨\u{200D}👩b", "", "✓",
  ]
  |> list.each(fn(s) { text.cell_width(s) |> should.equal(reference_width(s)) })
}

pub fn mixed_width_known_values_test() {
  text.cell_width("ok ✓ done") |> should.equal(9)
  text.cell_width("abc\u{FE0F}") |> should.equal(4)
  text.cell_width("a漢b") |> should.equal(4)
  text.cell_width("日本語 text 🚀") |> should.equal(14)
  text.cell_width(string.repeat("ab·", 100)) |> should.equal(300)
  int.to_string(text.cell_width("")) |> should.equal("0")
}
