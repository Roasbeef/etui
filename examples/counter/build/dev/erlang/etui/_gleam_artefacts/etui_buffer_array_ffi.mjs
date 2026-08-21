// JavaScript cell storage.
//
// A Buffer is immutable from Gleam's side, so a write has to leave the old
// value intact. Doing that by copying the whole array on every cell made
// filling a 200x50 buffer cost about 35 ms, more than a 60 fps frame budget
// on its own, because a full fill is then quadratic in the cell count.
//
// So writes come in batches. `draft` copies once, `draftSet` writes in place,
// and `commit` hands back an array again. The draft never escapes the loop
// that made it, so nothing else can observe the mutation.

// Cheap identity test: true when the two are the same object, false when they
// merely might be equal. Callers fall back to a structural compare.
export function same(a, b) {
  return a === b;
}

export function make(size, defaultValue) {
  return { data: new Array(size).fill(defaultValue), size, defaultValue };
}

export function get(index, arr) {
  if (index >= 0 && index < arr.size) return arr.data[index];
  return arr.defaultValue;
}

// A single write still copies. Callers writing more than one cell should take
// a draft instead.
export function set(index, value, arr) {
  const data = arr.data.slice();
  data[index] = value;
  return { data, size: arr.size, defaultValue: arr.defaultValue };
}

export function draft(arr) {
  return { data: arr.data.slice(), size: arr.size, defaultValue: arr.defaultValue };
}

export function draftSet(index, value, d) {
  if (index >= 0 && index < d.size) d.data[index] = value;
  return d;
}

export function draftGet(index, d) {
  if (index >= 0 && index < d.size) return d.data[index];
  return d.defaultValue;
}

export function commit(d) {
  return d;
}
