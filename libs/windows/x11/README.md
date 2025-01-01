# Z11

A X11 client library in Zig.

It has no dependencies and uses just Zig.

It is based on the material on the [docs](docs) folder and reading [libx11 source](https://gitlab.freedesktop.org/xorg/lib/libx11).

It is incomplete, missing specially:
- No extension support
- No concurrency
- No queue
- Missing some proto request type

But it seems to work.

For usage see the [documentation](https://diogok.github.io/z11) or the commented [src/demo.zig](src/demo.zig).

## License

MIT
