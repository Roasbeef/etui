/// Width measurement on strings that mix ASCII with other text.
///
/// Run: gleam run -m etui_width_bench
///
/// `reference` is what `text.cell_width` did to any string with one non-ASCII
/// byte in it: segment the whole string and add up the clusters. The first
/// table compares it with the current function on the same inputs, and the
/// second times the callers that measure a line more than once.
import etui/buffer
import etui/geometry
import etui/span
import etui/style
import etui/text
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/string

@target(erlang)
@external(erlang, "erlang", "monotonic_time")
fn now_native(unit: Micro) -> Int

@target(erlang)
type Micro {
  Microsecond
}

@target(erlang)
fn now_us() -> Int {
  now_native(Microsecond)
}

@target(javascript)
@external(javascript, "./bench_ffi.mjs", "nowMicros")
fn now_us() -> Int

fn repeat(n: Int, work: fn() -> a) -> a {
  case n <= 1 {
    True -> work()
    False -> {
      let _ = work()
      repeat(n - 1, work)
    }
  }
}

fn time(iterations: Int, work: fn() -> a) -> Float {
  let _ = work()
  let start = now_us()
  let _ = repeat(iterations, work)
  int.to_float(now_us() - start) /. int.to_float(iterations)
}

fn row(name: String, before: Float, after: Float) -> Nil {
  let ratio = float.to_string(round2(before /. after))
  io.println(
    text.pad_right(name, 34)
    <> text.pad_right(float.to_string(round2(before)) <> " us", 14)
    <> text.pad_right(float.to_string(round2(after)) <> " us", 14)
    <> ratio
    <> "x",
  )
}

fn round2(f: Float) -> Float {
  int.to_float(float.round(f *. 100.0)) /. 100.0
}

fn reference(s: String) -> Int {
  s
  |> string.to_graphemes
  |> list.fold(0, fn(acc, g) { acc + text.grapheme_cell_width(g) })
}

const ascii =
  "The quick brown fox jumps over the lazy dog and keeps running far away"

const sparse =
  "✓ built the package · 3 warnings › see the log — nothing else to report here"

const dense =
  "● ✓ ─ · › — ✓ ● ─ · › — 🚀 ✓ ● ─ · › — ✓ ● ─ · › — 🚀 ✓ ● ─ · › — ✓ ●"

const cjk = "日本語のテキストと English が混在する行 ✓ 完了しました 🚀 次へ進みます"

pub fn main() -> Nil {
  io.println("cell_width, microseconds per call")
  io.println(
    text.pad_right("input", 34)
    <> text.pad_right("grapheme", 14)
    <> text.pad_right("current", 14)
    <> "speedup",
  )
  [
    #("ascii", ascii),
    #("sparse glyphs", sparse),
    #("dense glyphs", dense),
    #("cjk and emoji", cjk),
  ]
  |> list.each(fn(case_) {
    let #(name, s) = case_
    row(
      name,
      time(20_000, fn() { reference(s) }),
      time(20_000, fn() { text.cell_width(s) }),
    )
  })

  io.println("")
  io.println("callers, microseconds per call")
  let area = geometry.rect_new(0, 0, 100, 1)
  let plain = style.new(style.Default, style.Default, style.none())
  let line = fn(s: String) {
    span.line_new([span.span_plain("› "), span.span_plain(s)])
  }
  let blank = buffer.buffer_new(area)
  [#("render_line sparse", sparse), #("render_line dense", dense)]
  |> list.each(fn(case_) {
    let #(name, s) = case_
    let l = line(s)
    let _ = plain
    let after =
      time(5000, fn() {
        span.render_line(blank, geometry.Position(0, 0), l, 100)
      })
    io.println(
      text.pad_right(name, 34) <> float.to_string(round2(after)) <> " us",
    )
  })
  [#("truncate sparse to 40", sparse), #("truncate dense to 40", dense)]
  |> list.each(fn(case_) {
    let #(name, s) = case_
    let after = time(20_000, fn() { text.truncate(s, 40, "…") })
    io.println(
      text.pad_right(name, 34) <> float.to_string(round2(after)) <> " us",
    )
  })
}
