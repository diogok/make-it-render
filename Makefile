
all: linux windows macos

clean:
	rm -rf zig-out zig-cache target

linux: x86_64-linux x86-linux aarch64-linux arm-linux riscv64-linux

x86_64-linux:
	zig build install -Dtarget=x86_64-linux-gnu
	mkdir -p target
	mv zig-out/bin/demo-x11 target/demo-x11-x86_64-linux-gnu
	ls -lah target/demo-x11-x86_64-linux-gnu

x86-linux:
	zig build -Dtarget=x86-linux-gnu
	mkdir -p target
	mv zig-out/bin/demo-x11 target/demo-x11-x86-linux-gnu
	ls -lah target/demo-x11-x86_64-linux-gnu

aarch64-linux:
	zig build -Dtarget=aarch64-linux-gnu
	mkdir -p target
	mv zig-out/bin/demo-x11 target/demo-x11-aarch64-linux-gnu
	ls -lah target/demo-x11-aarch64-linux-gnu

arm-linux:
	zig build -Dtarget=arm-linux-gnu
	mkdir -p target
	mv zig-out/bin/demo-x11 target/demo-x11-arm-linux-gnu
	ls -lah target/demo-x11-arm-linux-gnu

riscv64-linux:
	zig build -Dtarget=riscv64-linux-gnu
	mkdir -p target
	mv zig-out/bin/demo-x11 target/demo-x11-riscv64-linux-gnu
	ls -lah target/demo-x11-riscv64-linux-gnu

run-windows: 
	zig build install -Dtarget=x86_64-windows-gnu
	wine zig-out/bin/demo-windows.exe

windows: x86_64-windows x86-windows aarch64-windows

x86_64-windows:
	zig build install -Dtarget=x86_64-windows-gnu
	mkdir -p target
	mv zig-out/bin/demo-windows.exe target/demo-windows-x86_64.exe
	ls -lah target/demo-windows-x86_64.exe

x86-windows:
	# TODO: Not working
	#zig build -Dtarget=x86-windows-gnu -Doptimize=ReleaseSmall
	#mkdir -p target
	#mv zig-out/bin/demo-windows.exe target/demo-windows-x86.exe
	#ls -lah target/demo-windows-x86.exe

aarch64-windows:
	zig build install -Dtarget=aarch64-windows-gnu
	mkdir -p target
	mv zig-out/bin/demo-windows.exe target/demo-windows-aarch64.exe
	ls -lah target/demo-windows-aarch64.exe

macosx: x86_64-macosx aarch64-macosx

x86_64-macosx:
	zig build install -Dtarget=x86_64-macos.10.15-none
	mkdir -p target
	mv zig-out/bin/demo target/demo-macos-x86_64
	ls -lah target/demo-macos-x86_64

aarch64-macosx:
	zig build install -Dtarget=aarch64-macos
	mkdir -p target
	mv zig-out/bin/demo target/demo-macos-aarch64
	ls -lah target/demo-macos-aarch64

# TODO: FreeBSD
# TODO: NetBSD
# TODO: OpenBSD
