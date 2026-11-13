/// TUI-aware text handling. Cell-width semantics for terminals.
///
/// All `width` values are in **terminal cells**, not graphemes or codepoints:
///   - ASCII printable: 1 cell
///   - CJK / Hangul / Hiragana / Katakana / Fullwidth: 2 cells
///   - Emoji (including ZWJ sequences): 2 cells (first codepoint rule)
///   - Combining marks, ZWJ, variation selectors, zero-width formatters: 0 cells
///   - Ambiguous symbols (Misc Symbols U+2600–26FF, Dingbats U+2700–27BF):
///     1 cell, except the members of Unicode's `Emoji_Presentation` set,
///     which every modern terminal draws as 2.
///   - A variation selector decides the width of the symbol it follows:
///     U+FE0F asks for the emoji glyph (2 cells), U+FE0E for the text one.
///
/// Grapheme segmentation delegates to Erlang's native Unicode (UAX #29).
/// This correctly clusters ZWJ sequences, flag pairs, and combining marks.
///
/// **Limitation:** emoji whose width depends on terminal/font (e.g. keycap
/// sequences, skin-tone modifiers) are approximated as 2 cells. Behaviour
/// may differ on terminals that render them as narrow.
import gleam/bit_array
import gleam/int
import gleam/list
import gleam/result
import gleam/string

// ─────────────────────────────────────────────────────────────────
// Cell width

/// Split a string into grapheme clusters (UAX #29, via Erlang Unicode).
///
/// Each element is one user-perceived character: a base letter, a ZWJ
/// sequence, a flag pair, an emoji with modifiers, etc.
///
/// ```gleam
/// graphemes("café") // ["c", "a", "f", "é"]
/// graphemes("👨‍👩‍👧‍👦") // ["👨‍👩‍👧‍👦"], one cluster
/// ```
pub fn graphemes(s: String) -> List(String) {
  string.to_graphemes(s)
}

/// Cell width of a string (sum of grapheme widths).
///
/// Printable ASCII is measured a byte at a time, and only the stretches that
/// contain something else go through grapheme segmentation, so a transcript
/// line with one `✓` in it costs a few graphemes instead of all of them.
///
/// ```gleam
/// cell_width("ok ✓ done") // 9
/// ```
pub fn cell_width(s: String) -> Int {
  measure(bit_array.from_string(s), 0, NoBase)
}

// The ASCII character a scan has just counted, if the byte after it could still
// join its cluster. Only a printable one can be the base of a cluster that
// grows: every control character is a cluster of its own, and a line feed
// after a carriage return is the one pair of ASCII characters that share a
// cluster, both zero cells wide.
type Base {
  NoBase
  Base(byte: Int)
}

// Walks the string a byte at a time. Printable ASCII is one cell. A control
// character is none, and ends any base. A codepoint that cannot join a
// neighbouring cluster (`standalone`) is measured by itself, and the first one
// that can hands the scan to `measure_region`.
fn measure(bytes: BitArray, width: Int, base: Base) -> Int {
  case bytes {
    <<>> -> width
    <<a:8, b:8, c:8, d:8, rest:bits>>
      if a >= 0x20
      && a <= 0x7E
      && b >= 0x20
      && b <= 0x7E
      && c >= 0x20
      && c <= 0x7E
      && d >= 0x20
      && d <= 0x7E
    -> measure(rest, width + 4, Base(d))
    <<byte:8, rest:bits>> if byte >= 0x20 && byte <= 0x7E ->
      measure(rest, width + 1, Base(byte))
    <<byte:8, rest:bits>> if byte < 0x80 -> measure(rest, width, NoBase)
    _ -> {
      let #(n, rest) = decode_codepoint(bytes)
      case standalone(n) && next_is_standalone(rest) {
        True -> measure(rest, width + codepoint_cell_width(n), NoBase)

        // A codepoint that is itself standalone but has a neighbour that is not
        // cannot attach to the base before it, so that base stays counted.
        False ->
          case standalone(n) {
            True -> measure_region(bytes, width, NoBase)
            False -> measure_region(bytes, width, base)
          }
      }
    }
  }
}

// The codepoint at the front of `bytes`, which starts with a UTF-8 lead byte,
// and what follows it. This reads the bytes itself because UTF-codepoint
// patterns do not exist on the JavaScript target. The string was valid UTF-8
// when it came in and every cut lands on a character boundary, so the last
// arm is unreachable.
fn decode_codepoint(bytes: BitArray) -> #(Int, BitArray) {
  case bytes {
    <<b1:8, b2:8, rest:bits>> if b1 >= 0xC0 && b1 < 0xE0 -> #(
      { b1 - 0xC0 } * 64 + { b2 - 0x80 },
      rest,
    )
    <<b1:8, b2:8, b3:8, rest:bits>> if b1 >= 0xE0 && b1 < 0xF0 -> #(
      { b1 - 0xE0 } * 4096 + { b2 - 0x80 } * 64 + { b3 - 0x80 },
      rest,
    )
    <<b1:8, b2:8, b3:8, b4:8, rest:bits>> if b1 >= 0xF0 -> #(
      { b1 - 0xF0 }
        * 262_144
        + { b2 - 0x80 }
        * 4096
        + { b3 - 0x80 }
        * 64
        + { b4 - 0x80 },
      rest,
    )
    _ -> #(0, <<>>)
  }
}

// Whether the next character is one the scan can take whole: the end of the
// string, any ASCII byte, or a standalone codepoint.
fn next_is_standalone(rest: BitArray) -> Bool {
  case rest {
    <<>> -> True
    <<byte:8, _:bits>> if byte < 0x80 -> True
    _ -> standalone(decode_codepoint(rest).0)
  }
}

// A codepoint is standalone when no grapheme rule joins it to a neighbour
// that is itself ASCII or standalone. That excludes everything that is Extend,
// ZWJ, SpacingMark or Prepend (which join what is beside them), regional
// indicators and Hangul jamo (which pair with each other), and the Indic
// scripts (conjuncts). What is listed is the Latin, Greek and Cyrillic text,
// the punctuation, arrows, mathematical, technical, box drawing, geometric,
// dingbat and symbol blocks, kana, Han ideographs, Hangul syllables and the
// emoji blocks above the skin tone modifiers, which is what terminal output is
// made of. Two of them side by side never share a cluster, so a standalone
// codepoint is its own cluster whenever its neighbours are standalone or ASCII.
fn standalone(cp: Int) -> Bool {
  case cp {
    n if n >= 0xA0 && n <= 0x2FF -> True
    n if n >= 0x370 && n <= 0x3FF -> True
    n if n >= 0x400 && n <= 0x482 -> True
    n if n >= 0x48A && n <= 0x52F -> True
    n if n >= 0x2010 && n <= 0x2027 -> True
    n if n >= 0x2030 && n <= 0x205E -> True
    n if n >= 0x2190 && n <= 0x27BF -> True
    n if n >= 0x2B00 && n <= 0x2BFF -> True
    n if n >= 0x3041 && n <= 0x3096 -> True
    n if n >= 0x30A1 && n <= 0x30FA -> True
    n if n >= 0x3400 && n <= 0x4DBF -> True
    n if n >= 0x4E00 && n <= 0x9FFF -> True
    n if n >= 0xAC00 && n <= 0xD7A3 -> True
    n if n >= 0x1F300 && n <= 0x1F3FA -> True
    n if n >= 0x1F400 && n <= 0x1FAFF -> True
    _ -> False
  }
}

// Measures one stretch that segmentation has to see, then resumes the byte
// scan after it. A combining mark, variation selector or joiner after an
// ASCII character changes that character's cluster, so the stretch starts at
// the ASCII character before the first non-ASCII byte, which is taken back out
// of the running width. A prepended mark changes the cluster of the character
// after it, which is why `take_region` keeps the one printable ASCII character
// that follows. The stretch always begins and ends at a cluster boundary: two
// printable ASCII characters never share a cluster, so measuring each side
// separately gives what measuring the whole string would.
fn measure_region(bytes: BitArray, width: Int, base: Base) -> Int {
  let #(region, rest) = case base {
    NoBase -> take_region(bytes, <<>>)
    Base(byte:) -> take_region(bytes, <<byte:8>>)
  }
  let carried = case base {
    NoBase -> width
    Base(..) -> width - 1
  }
  measure(rest, carried + clusters_width(region), NoBase)
}

// Splits the stretch off the front of `bytes`. It takes every non-ASCII byte,
// and a printable ASCII character that sits between two non-ASCII bytes, since
// nothing separates it from them. The first printable ASCII character that has
// ASCII or the end of the string after it is the last one taken. A control
// character is a boundary on both sides, so it is left for `measure`.
fn take_region(bytes: BitArray, region: BitArray) -> #(BitArray, BitArray) {
  case bytes {
    <<byte:8, rest:bits>> if byte >= 0x80 ->
      take_region(rest, <<region:bits, byte:8>>)
    <<byte:8, rest:bits>> if byte >= 0x20 && byte <= 0x7E ->
      case rest {
        <<next:8, _:bits>> if next >= 0x80 ->
          take_region(rest, <<region:bits, byte:8>>)
        _ -> #(<<region:bits, byte:8>>, rest)
      }
    _ -> #(region, bytes)
  }
}

// The stretch is whole characters cut at ASCII bytes, so it is valid UTF-8
// and the empty string is only the unreachable fallback.
fn clusters_width(region: BitArray) -> Int {
  region
  |> bit_array.to_string
  |> result.unwrap("")
  |> string.to_graphemes
  |> list.fold(0, fn(acc, g) { acc + grapheme_cell_width(g) })
}

/// Cell width of a single grapheme cluster.
///
/// The base codepoint's East Asian Width / emoji classification decides the
/// width, and the codepoint immediately after it can override that when it is
/// a variation selector. Everything further into the cluster (combining marks,
/// ZWJ, the rest of a sequence) contributes nothing.
///
/// ```gleam
/// grapheme_cell_width("☺")   // 1, the text glyph
/// grapheme_cell_width("☺\u{FE0F}") // 2, VS16 asked for the emoji glyph
/// ```
pub fn grapheme_cell_width(g: String) -> Int {
  case bit_array.from_string(g) {
    <<byte:8>> if byte < 0x20 || byte == 0x7F -> 0
    <<byte:8>> if byte <= 0x7E -> 1
    _ -> unicode_grapheme_width(g)
  }
}

// Non-ASCII clusters retain the Unicode and presentation-selector rules.
fn unicode_grapheme_width(g: String) -> Int {
  case string.to_utf_codepoints(g) {
    [] -> 0
    [cp] -> codepoint_cell_width(string.utf_codepoint_to_int(cp))

    // A variation selector is the only codepoint in a cluster that can change
    // how wide the base is drawn, and it is always the one straight after it.
    [cp, next, ..] ->
      presentation_width(
        string.utf_codepoint_to_int(cp),
        string.utf_codepoint_to_int(next),
      )
  }
}

/// Width of `base` once the codepoint after it has had its say.
///
/// U+FE0F (VS16) requests the emoji glyph, which is two cells wide, and U+FE0E
/// (VS15) requests the text glyph, which is one. VS15 only demotes a base
/// below U+1F000: above that there is no text glyph to fall back to, so a
/// terminal draws the emoji wide whatever the selector asks for.
fn presentation_width(base: Int, next: Int) -> Int {
  case next {
    0xFE0F -> 2
    0xFE0E ->
      case base < 0x1F000 {
        True -> 1
        False -> codepoint_cell_width(base)
      }
    _ -> codepoint_cell_width(base)
  }
}

/// Cell width of a single Unicode codepoint.
/// Returns 0 for control / combining / zero-width, 2 for wide (CJK / emoji /
/// fullwidth), 1 otherwise.
pub fn codepoint_cell_width(cp: Int) -> Int {
  case cp {
    // C0 controls + DEL
    n if n < 0x20 -> 0
    0x7F -> 0
    // Combining diacritical marks
    n if n >= 0x0300 && n <= 0x036F -> 0
    // Hangul Jamo medial vowels + final consonants (combining)
    n if n >= 0x1160 && n <= 0x11FF -> 0
    // Variation selectors
    n if n >= 0xFE00 && n <= 0xFE0F -> 0
    n if n >= 0xE0100 && n <= 0xE01EF -> 0
    // Zero-width formatters: ZWSP, ZWNJ, ZWJ, BOM
    0x200B | 0x200C | 0x200D | 0xFEFF -> 0

    // ── Wide (East Asian Wide / Fullwidth) ─────────────────────────
    // Hangul Jamo initial consonants
    n if n >= 0x1100 && n <= 0x115F -> 2
    // CJK Radicals + Symbols + Punctuation
    n if n >= 0x2E80 && n <= 0x303E -> 2
    // Hiragana, Katakana, Bopomofo, Hangul Compat, CJK Strokes, etc.
    n if n >= 0x3041 && n <= 0x33FF -> 2
    // CJK Extension A
    n if n >= 0x3400 && n <= 0x4DBF -> 2
    // CJK Unified Ideographs
    n if n >= 0x4E00 && n <= 0x9FFF -> 2
    // Yi Syllables/Radicals
    n if n >= 0xA000 && n <= 0xA4CF -> 2
    // Hangul Syllables
    n if n >= 0xAC00 && n <= 0xD7A3 -> 2
    // CJK Compatibility Ideographs
    n if n >= 0xF900 && n <= 0xFAFF -> 2
    // CJK Compatibility Forms
    n if n >= 0xFE30 && n <= 0xFE4F -> 2
    // Fullwidth Forms (NOT halfwidth section 0xFF61–0xFFDC which is width 1)
    n if n >= 0xFF00 && n <= 0xFF60 -> 2
    // Fullwidth Signs
    n if n >= 0xFFE0 && n <= 0xFFE6 -> 2

    // ── Emoji ──────────────────────────────────────────────────────
    // Misc Symbols (0x2600..0x26FF) and Dingbats (0x2700..0x27BF) are not
    // ranges here, because the block does not decide the width: ✦ ★ ◆ ☆ are
    // Ambiguous and one cell, ⚡ ✅ ❌ two. `emoji_presentation_width` below
    // separates them by the per-codepoint Unicode property, which is the only
    // thing that does.
    // Regional Indicator Symbols (flags pair into 2 cells)
    n if n >= 0x1F1E6 && n <= 0x1F1FF -> 2
    // Misc Symbols and Pictographs
    n if n >= 0x1F300 && n <= 0x1F5FF -> 2
    // Emoticons
    n if n >= 0x1F600 && n <= 0x1F64F -> 2
    // Transport and Map Symbols
    n if n >= 0x1F680 && n <= 0x1F6FF -> 2
    // Alchemical Symbols
    n if n >= 0x1F700 && n <= 0x1F77F -> 2
    // Geometric Shapes Extended
    n if n >= 0x1F780 && n <= 0x1F7FF -> 2
    // Supplemental Arrows-C
    n if n >= 0x1F800 && n <= 0x1F8FF -> 2
    // Supplemental Symbols and Pictographs
    n if n >= 0x1F900 && n <= 0x1F9FF -> 2
    // Symbols and Pictographs Extended-A
    n if n >= 0x1FA00 && n <= 0x1FAFF -> 2

    // CJK Extensions B, C, D, E, F, G
    n if n >= 0x20000 && n <= 0x2FFFD -> 2
    n if n >= 0x30000 && n <= 0x3FFFD -> 2

    // Nothing above settled it by block, so the codepoint is one cell unless
    // it is one of the emoji that live in an otherwise narrow block.
    n -> emoji_presentation_width(n)
  }
}

/// Two cells for the code points whose Unicode `Emoji_Presentation` is `Yes`
/// and which `codepoint_cell_width` has not already made wide by block, one
/// cell for everything else.
///
/// These blocks cannot be decided by range. Miscellaneous Symbols holds ☆ ★ ☎
/// alongside ⚡ ⛔ ☔, and Dingbats holds ✦ ✓ ✗ alongside ✅ ❌ ❗; the first
/// group is East Asian Ambiguous and one cell, the second is drawn as colour
/// emoji two cells wide. Only the per-code-point property tells them apart, so
/// its members are listed rather than approximated, and an earlier attempt to
/// widen the whole block instead is what made buffer positions drift past the
/// cursor for ✦ ★ ◆.
///
/// The set is Unicode 16.0's `Emoji_Presentation` (emoji-data.txt, 2024-05-01)
/// restricted to the code points below U+1F300, since everything from there up
/// is already wide by block above. Re-derive it from that file rather than by
/// hand if a later Unicode version adds to it.
fn emoji_presentation_width(cp: Int) -> Int {
  case cp {
    // Miscellaneous Technical: ⌚⌛ ⏩⏪⏫⏬ ⏰ ⏳
    n if n >= 0x231A && n <= 0x231B -> 2
    n if n >= 0x23E9 && n <= 0x23EC -> 2
    0x23F0 -> 2
    0x23F3 -> 2

    // Geometric Shapes: ◽◾
    n if n >= 0x25FD && n <= 0x25FE -> 2

    // Miscellaneous Symbols: ☔☕ ♈♉♊♋♌♍♎♏♐♑♒♓ ♿ ⚓ ⚡ ⚪⚫ ⚽⚾ ⛄⛅ ⛎ ⛔ ⛪ ⛲⛳ ⛵ ⛺ ⛽
    n if n >= 0x2614 && n <= 0x2615 -> 2
    n if n >= 0x2648 && n <= 0x2653 -> 2
    0x267F -> 2
    0x2693 -> 2
    0x26A1 -> 2
    n if n >= 0x26AA && n <= 0x26AB -> 2
    n if n >= 0x26BD && n <= 0x26BE -> 2
    n if n >= 0x26C4 && n <= 0x26C5 -> 2
    0x26CE -> 2
    0x26D4 -> 2
    0x26EA -> 2
    n if n >= 0x26F2 && n <= 0x26F3 -> 2
    0x26F5 -> 2
    0x26FA -> 2
    0x26FD -> 2

    // Dingbats: ✅ ✊✋ ✨ ❌ ❎ ❓❔❕ ❗ ➕➖➗ ➰ ➿
    0x2705 -> 2
    n if n >= 0x270A && n <= 0x270B -> 2
    0x2728 -> 2
    0x274C -> 2
    0x274E -> 2
    n if n >= 0x2753 && n <= 0x2755 -> 2
    0x2757 -> 2
    n if n >= 0x2795 && n <= 0x2797 -> 2
    0x27B0 -> 2
    0x27BF -> 2

    // Miscellaneous Symbols and Arrows: ⬛⬜ ⭐ ⭕
    n if n >= 0x2B1B && n <= 0x2B1C -> 2
    0x2B50 -> 2
    0x2B55 -> 2

    // Enclosed alphanumerics and ideographs: 🀄 🃏 🆎 🆑🆒🆓🆔🆕🆖🆗🆘🆙🆚 🈁 🈚 🈯 🈲🈳🈴🈵🈶 🈸🈹🈺 🉐🉑
    0x1F004 -> 2
    0x1F0CF -> 2
    0x1F18E -> 2
    n if n >= 0x1F191 && n <= 0x1F19A -> 2
    0x1F201 -> 2
    0x1F21A -> 2
    0x1F22F -> 2
    n if n >= 0x1F232 && n <= 0x1F236 -> 2
    n if n >= 0x1F238 && n <= 0x1F23A -> 2
    n if n >= 0x1F250 && n <= 0x1F251 -> 2

    _ -> 1
  }
}

// ─────────────────────────────────────────────────────────────────
// Text operations (cell-aware)

pub type Alignment {
  Left
  Center
  Right
}

/// Truncate to max_width cells. Appends ellipsis only if truncation occurs.
/// The ellipsis itself counts toward the budget.
pub fn truncate(s: String, max_width: Int, ellipsis: String) -> String {
  case max_width {
    w if w <= 0 -> ""
    _ -> {
      let s_width = cell_width(s)
      case s_width <= max_width {
        True -> s
        False -> {
          let ellipsis_width = cell_width(ellipsis)
          let available = int.max(0, max_width - ellipsis_width)
          let gs = string.to_graphemes(s)
          take_prefix(gs, available, 0, "") <> ellipsis
        }
      }
    }
  }
}

fn take_prefix(
  graphemes: List(String),
  available: Int,
  width: Int,
  acc: String,
) -> String {
  case graphemes {
    [] -> acc
    [g, ..rest] -> {
      let g_width = grapheme_cell_width(g)
      case width + g_width <= available {
        True -> take_prefix(rest, available, width + g_width, acc <> g)
        False -> acc
      }
    }
  }
}

/// Word-wrap to max_width cells.
///
/// Line endings are normalised first: `\r\n` and lone `\r` both become `\n`.
/// A raw `\r` left in the output would occupy zero cells and desynchronise
/// every position after it.
///
/// Tabs are expanded to spaces at 8-column tab stops before wrapping, so a
/// tab never reaches the buffer (control characters are dropped there).
///
/// Returns a list of lines, each at most `max_width` cells wide, with one
/// exception: a line always takes at least one grapheme, so a grapheme wider
/// than `max_width` (a CJK character at a width of 1) gets a line to itself
/// and that line overflows by the grapheme's excess.
pub fn wrap(s: String, max_width: Int) -> List(String) {
  case max_width {
    w if w <= 0 -> []
    _ ->
      s
      |> normalise_newlines
      |> expand_tabs(8)
      |> string.split("\n")
      |> list.flat_map(fn(para) { wrap_para(para, max_width) })
  }
}

/// Normalise `\r\n` and lone `\r` to `\n`.
///
/// No `string.contains(s, "\r")` fast path: `\r\n` is a single grapheme
/// cluster, so `contains` reports False for a `\r` that is followed by `\n`,
/// which is exactly the case this needs to catch.
pub fn normalise_newlines(s: String) -> String {
  s
  |> string.replace("\r\n", "\n")
  |> string.replace("\r", "\n")
}

/// Expand tab characters to spaces, advancing to the next multiple of
/// `tab_width` cells. Newlines reset the column counter.
///
/// ```gleam
/// text.expand_tabs("a\tb", 4)  // "a   b"
/// ```
pub fn expand_tabs(s: String, tab_width: Int) -> String {
  case string.contains(s, "\t") {
    False -> s
    True ->
      expand_tabs_loop(string.to_graphemes(s), int.max(1, tab_width), 0, [])
  }
}

// Pieces accumulate newest-first and are joined once. Appending to the string
// on every grapheme would copy the whole accumulator each time, which is
// O(n^2) in the length of the line.
fn expand_tabs_loop(
  gs: List(String),
  tab_width: Int,
  col: Int,
  rev_acc: List(String),
) -> String {
  case gs {
    [] -> string.concat(list.reverse(rev_acc))
    ["\t", ..rest] -> {
      let pad = tab_width - col % tab_width
      expand_tabs_loop(rest, tab_width, col + pad, [
        string.repeat(" ", pad),
        ..rev_acc
      ])
    }
    ["\n", ..rest] -> expand_tabs_loop(rest, tab_width, 0, ["\n", ..rev_acc])
    [g, ..rest] ->
      expand_tabs_loop(rest, tab_width, col + grapheme_cell_width(g), [
        g,
        ..rev_acc
      ])
  }
}

fn wrap_para(s: String, max_width: Int) -> List(String) {
  // An empty paragraph produces one blank line (not zero lines).
  case s {
    "" -> [""]
    _ -> wrap_para_words(s, max_width)
  }
}

fn wrap_para_words(s: String, max_width: Int) -> List(String) {
  // The line being built is kept as its words, newest first, next to its
  // width. Both matter: measuring the joined line on every word walks its
  // graphemes again and again, and rebuilding it with <> copies it again and
  // again, so a long line cost time quadratic in its own length. Each word is
  // now measured once and each line joined once.
  let #(rev_lines, rev_current, _) =
    list.fold(string.split(s, " "), #([], [], 0), fn(acc, word) {
      let #(lines, current, width) = acc
      let word_width = cell_width(word)
      let gap = case current {
        [] -> 0
        _ -> 1
      }
      case width + gap + word_width <= max_width {
        True -> #(lines, [word, ..current], width + gap + word_width)
        False -> {
          let closed = case current {
            [] -> lines
            _ -> [join_words(current), ..lines]
          }
          case word_width <= max_width {
            True -> #(closed, [word], word_width)
            False -> {
              // Wider than the whole line: break it, and carry the last piece
              // on as the start of the next line.
              case list.reverse(hard_break_word(word, max_width)) {
                [] -> #(closed, [], 0)
                [last, ..rest_rev] -> #(
                  list.append(rest_rev, closed),
                  [last],
                  cell_width(last),
                )
              }
            }
          }
        }
      }
    })
  let all_rev = case rev_current {
    [] -> rev_lines
    _ -> [join_words(rev_current), ..rev_lines]
  }
  list.reverse(all_rev)
}

fn join_words(rev_words: List(String)) -> String {
  string.join(list.reverse(rev_words), " ")
}

// Split a single token into chunks of at most max_width cells.
// Always produces at least one chunk even if a single grapheme is wider than max_width.
//
// Both the chunk list and the current chunk accumulate newest-first and are
// reversed once, so a long token (a CJK paragraph is one token, it has no
// spaces) costs O(n) rather than O(n^2) in list appends and string copies.
fn hard_break_word(s: String, max_width: Int) -> List(String) {
  hard_break_acc(string.to_graphemes(s), max_width, 0, [], [])
}

fn hard_break_acc(
  gs: List(String),
  max_width: Int,
  curr_w: Int,
  rev_curr: List(String),
  rev_acc: List(String),
) -> List(String) {
  case gs {
    [] ->
      case rev_curr {
        [] -> list.reverse(rev_acc)
        _ -> list.reverse([join_rev(rev_curr), ..rev_acc])
      }
    [g, ..rest] -> {
      let gw = grapheme_cell_width(g)
      // Flush when adding g would exceed max_width (but always accept the first grapheme).
      case curr_w > 0 && curr_w + gw > max_width {
        True ->
          hard_break_acc(rest, max_width, gw, [g], [
            join_rev(rev_curr),
            ..rev_acc
          ])
        False ->
          hard_break_acc(rest, max_width, curr_w + gw, [g, ..rev_curr], rev_acc)
      }
    }
  }
}

fn join_rev(rev_pieces: List(String)) -> String {
  string.concat(list.reverse(rev_pieces))
}

/// Pad right with spaces to reach `width` cells. Cell-aware.
pub fn pad_right(s: String, width: Int) -> String {
  let cw = cell_width(s)
  case cw >= width {
    True -> s
    False -> s <> string.repeat(" ", width - cw)
  }
}

/// Pad left with spaces to reach `width` cells. Cell-aware.
pub fn pad_left(s: String, width: Int) -> String {
  let cw = cell_width(s)
  case cw >= width {
    True -> s
    False -> string.repeat(" ", width - cw) <> s
  }
}

/// Align left/center/right within `width` cells. Cell-aware.
pub fn align(s: String, width: Int, alignment: Alignment) -> String {
  case alignment {
    Left -> pad_right(s, width)
    Right -> pad_left(s, width)
    Center -> {
      let cw = cell_width(s)
      case cw >= width {
        True -> s
        False -> {
          let total = width - cw
          let left = total / 2
          let right = total - left
          string.repeat(" ", left) <> s <> string.repeat(" ", right)
        }
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────
// ANSI stripping

/// Strip ANSI escape sequences. Handles CSI (`\e[…<final>`) and OSC
/// (`\e]…ST`/`\e]…BEL`) sequences.
pub fn strip_ansi(s: String) -> String {
  strip_loop(string.to_graphemes(s), "", Plain)
}

type StripState {
  Plain
  EscSeen
  CsiBody
  OscBody
  OscEscSeen
}

fn strip_loop(gs: List(String), acc: String, state: StripState) -> String {
  case gs {
    [] -> acc
    [g, ..rest] -> {
      let #(new_acc, new_state) = case state, g {
        Plain, "\u{001B}" -> #(acc, EscSeen)
        Plain, _ -> #(acc <> g, Plain)
        EscSeen, "[" -> #(acc, CsiBody)
        EscSeen, "]" -> #(acc, OscBody)
        // Other ESC <char> two-byte sequences (charset switch, etc.), drop both
        EscSeen, _ -> #(acc, Plain)
        // CSI body terminates on any byte in 0x40..0x7E (final byte)
        CsiBody, c -> {
          case is_csi_final(c) {
            True -> #(acc, Plain)
            False -> #(acc, CsiBody)
          }
        }
        // OSC body terminates on BEL (0x07) or ST (ESC \\)
        OscBody, "\u{0007}" -> #(acc, Plain)
        OscBody, "\u{001B}" -> #(acc, OscEscSeen)
        OscBody, _ -> #(acc, OscBody)
        OscEscSeen, "\\" -> #(acc, Plain)
        OscEscSeen, _ -> #(acc, OscBody)
      }
      strip_loop(rest, new_acc, new_state)
    }
  }
}

fn is_csi_final(g: String) -> Bool {
  case string.to_utf_codepoints(g) {
    [cp, ..] -> {
      let n = string.utf_codepoint_to_int(cp)
      n >= 0x40 && n <= 0x7E
    }
    [] -> False
  }
}
