# Make it render

This is a Zig library for cross-platform window handling and basic rendering, without any dependencies.

It is an experimental project with constant changes.

## What is this

- Glue code and abstraction between X11, Windows and MacOS(soon?) window and input handling
- Support window management, input events and rendering
- It only uses C when linking to win32 required libraries
- Produces small binaries, relatively fast
- Render text
- No dependencies

## What this is not

- It is not a GUI library or game engine
- It does not use GPU (no opengl nor vulkan)
- It does not support mobile (no Android nor iOS)

## Structure

Each module is independent, should be usable, and them there some "glue" modules to make it all work.

- anywindow: Window handling abstraction
	- macos
	- x11
	- windows
- text: Read fonts, get glyphs, work with unicode
	- fonts: embed unifont and terminus
	- bdf: BDF parsing
- glue.zig: Joins everything

## Work in progress

Notably missing:

- Improve keyboard handling
- Fullscreen windows and back
- Icons
- Image drawing, like from PNGs or other image formats
- Wayland support
- MacOS support
- Check changes in DPI

## Usage

To do.

See [src/demo.zig] for an example.

## License 

MIT
