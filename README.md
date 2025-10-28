# Make it render

Glue code and abstraction between X11, Windows and MacOS windows handling.

Or the minimum it takes to render pixels on a desktop.

It is highly experimental and immature yet, with constant changes and bad performance.

It does work, can render text to a window and receive input events.

## What is this

This is a dependency-less Zig library for cross-platform window and rendering.

It only uses C when linking to win32 required libraries.

Produces small binaries, specially with 

## What this is not

It is not a GUI library or game engine. 

It does not use GPU (no opengl or vulkan).

It does not support mobile (Android, iOS).

## Work in progress

Notably missing:

- Performance (can barely hold 60fps on a raspberry pi 5)
- Image drawing (like from PNGs)
- Wayland support (works under X11 and XWayland)
- MacOS support

## Usage

To do.

See [src/demo.zig].

## License 

MIT
