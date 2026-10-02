# image

Shows a PNG inline. At launch it asks the terminal what it can draw, then
draws the image in a bordered box that follows the window as it resizes:
through placeholder cells in kitty and Ghostty, with OSC 1337 in iTerm2, and
as a line of text anywhere else. Inside Herdr or under `NO_COLOR` it does not
ask.

```sh
gleam run                       # etui's logo, ../../assets/logo.png
gleam run -- path/to/file.png   # any PNG
```

Keys: `q` quit. The terminal's answer is printed after the app exits, for
example:

```text
kitty graphics: yes · iTerm2 images: no · cell: 10x21 px · terminal: ghostty 1.2.0
```

See [docs/graphics.md](../../docs/graphics.md).
