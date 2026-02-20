
all: build

build:
	zig build

run:
	zig build run

test:
	zig build test
	@for dir in $$(ls -d src/*/); do \
		echo $$dir; \
		cd $$dir && zig build test; \
		cd ../.. ;\
	done
