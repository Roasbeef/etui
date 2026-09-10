//// A real terminal probe for control-key delivery and continued output.
//// Each acknowledgement occupies a new row so frame diffs retain its marker.

import etui/app
import etui/backend
import etui/backend/default
import etui/buffer
import etui/geometry.{type Rect}
import etui/widgets/paragraph

type Model {
  Ready
  Saved
  Continued
  Finished
}

/// Run the probe driven by `dev/pty_flow_control_check.py`.
pub fn main() {
  let _ = app.run_buffered(default.new(), Ready, view, update, finished, 16)
  Nil
}

fn finished(model: Model) -> Bool {
  model == Finished
}

fn view(model: Model, screen: Rect) -> buffer.Buffer {
  let text = case model {
    Ready -> "FLOW_READY"
    Saved -> "FLOW_READY\nCTRL_S_RECEIVED"
    Continued | Finished -> "FLOW_READY\nCTRL_S_RECEIVED\nOUTPUT_CONTINUES"
  }
  buffer.buffer_new(screen)
  |> paragraph.render(screen, paragraph.paragraph_new(text))
}

fn update(event: backend.InputEvent, model: Model) -> Model {
  case event, model {
    backend.KeyPress("ctrl+s"), Ready -> Saved
    backend.KeyPress("x"), Saved -> Continued
    backend.KeyPress("q"), _ -> Finished
    _, _ -> model
  }
}
