// The long-word wrap test times itself, and gleam_stdlib has no clock.
export function monotonic_ms() {
  return Math.floor(performance.now());
}
