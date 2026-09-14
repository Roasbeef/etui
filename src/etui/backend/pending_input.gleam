/// Resolves incomplete terminal input when a read produces no more bytes.
///
/// A non-blocking burst probe cannot tell a standalone Escape key from the
/// beginning of a longer escape sequence. The first such probe therefore
/// preserves the remainder. A later empty probe resolves it, which keeps an
/// application that deliberately polls with a zero timeout from retaining an
/// Escape key forever.
import etui/backend.{type InputEvent}
import etui/input

@internal
pub fn after_empty_read(
  remainder: String,
  timeout_ms: Int,
  already_deferred: Bool,
) -> #(List(InputEvent), String, Bool) {
  case remainder, timeout_ms <= 0, already_deferred {
    "", _, _ -> #([], "", False)
    _, True, False -> #([], remainder, True)
    _, _, _ -> #(input.flush(remainder), "", False)
  }
}
