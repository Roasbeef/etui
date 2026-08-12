// Microsecond clock for the benchmark. performance.now() is milliseconds with
// a fractional part, which is the best resolution the platform offers.
export function nowMicros() {
  return Math.round(performance.now() * 1000);
}
