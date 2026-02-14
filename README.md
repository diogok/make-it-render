# Make it render

This is a Zig library for cross-platform window handling and basic rendering, without any dependencies.

It is an experimental project with constant changes.

## What this is

- Glue code and abstraction between X11, Windows and MacOS(soon?) window and input handling
- Support window management, input events and rendering
- Basic text and images drawing
- It only uses C when linking to win32 required libraries
- Produces small and performant binaries
- No dependencies
- All in one

## What this is not

- It is not a GUI library or game engine
- It does not use GPU (no opengl nor vulkan)
- It does not support mobile (no Android nor iOS)

## Structure

Each module is independent, should be usable by itself if wanted, and them there is some "glue" modules to make it all work togheter.

- anywindow: Window handling abstraction
	- macos
	- x11
	- windows
- text: Read fonts, get glyphs, work with unicode
	- fonts: embed unifont and terminus
	- bdf: BDF parsing
- image: Read images
	- pbm: Read from PBM format
- glue.zig: Joins everything
	- canvas: Infinit drawing canvas
	- image: Image scaling

## Work in progress

Notably missing:

- Wayland support
- MacOS support

## Usage

To do.

See [src/demo.zig](src/demo.zig) for an example.

## License 

MIT
