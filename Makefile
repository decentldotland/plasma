.PHONY: build check

build:
	mkdir -p build
	for f in src/*.tl; do \
		[ -e "$$f" ] || exit 0; \
		out="build/$${f#src/}"; \
		out="$${out%.tl}.lua"; \
		mkdir -p "$$(dirname "$$out")"; \
		tl gen -o "$$out" "$$f"; \
	done

check:
	tl check src/xbeam-bp.tl
