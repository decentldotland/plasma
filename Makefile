.PHONY: build build-vault build-orderbook check deploy vault

AMALG ?= /usr/local/bin/amalg.lua

build:
	rm -rf build build-lua
	mkdir -p build build-lua
	# Vault bundle: compile only vault + utils, then amalgamate
	tl gen -o build-lua/vault/main.lua src/vault/main.tl
	for f in src/vault/*.tl src/utils/*.tl; do \
		[ -e "$$f" ] || continue; \
		out="build-lua/$${f#src/}"; \
		out="$${out%.tl}.lua"; \
		mkdir -p "$$(dirname "$$out")"; \
		tl gen -o "$$out" "$$f"; \
	done
	LUA_PATH="build-lua/?.lua;build-lua/?/init.lua;;" \
	$(AMALG) -s build-lua/vault/main.lua -o build/vault.lua \
		vault.main \
		vault.handlers vault.types vault.helpers vault.patch \
		utils.types utils.deps utils.validation

	# Orderbook bundle: compile only orderbook + utils, then amalgamate
	tl gen -o build-lua/orderbook/main.lua src/orderbook/main.tl
	for f in src/orderbook/*.tl src/utils/*.tl; do \
		[ -e "$$f" ] || continue; \
		out="build-lua/$${f#src/}"; \
		out="$${out%.tl}.lua"; \
		mkdir -p "$$(dirname "$$out")"; \
		tl gen -o "$$out" "$$f"; \
	done
	LUA_PATH="build-lua/?.lua;build-lua/?/init.lua;;" \
	$(AMALG) -s build-lua/orderbook/main.lua -o build/orderbook.lua \
		orderbook.main \
		orderbook.handlers orderbook.types \
		utils.types utils.deps utils.validation

build-vault:
	mkdir -p build build-lua build-lua/vault
	tl gen -o build-lua/vault/main.lua src/vault/main.tl
	for f in src/vault/*.tl src/utils/*.tl; do \
		[ -e "$$f" ] || continue; \
		out="build-lua/$${f#src/}"; \
		out="$${out%.tl}.lua"; \
		mkdir -p "$$(dirname "$$out")"; \
		tl gen -o "$$out" "$$f"; \
	done
	LUA_PATH="build-lua/?.lua;build-lua/?/init.lua;;" \
	$(AMALG) -s build-lua/vault/main.lua -o build/vault.lua \
		vault.main \
		vault.handlers vault.types vault.helpers vault.patch \
		utils.types utils.deps utils.validation

build-orderbook:
	mkdir -p build build-lua build-lua/orderbook
	tl gen -o build-lua/orderbook/main.lua src/orderbook/main.tl
	for f in src/orderbook/*.tl src/utils/*.tl; do \
		[ -e "$$f" ] || continue; \
		out="build-lua/$${f#src/}"; \
		out="$${out%.tl}.lua"; \
		mkdir -p "$$(dirname "$$out")"; \
		tl gen -o "$$out" "$$f"; \
	done
	LUA_PATH="build-lua/?.lua;build-lua/?/init.lua;;" \
	$(AMALG) -s build-lua/orderbook/main.lua -o build/orderbook.lua \
		orderbook.main \
		orderbook.handlers orderbook.types \
		utils.types utils.deps utils.validation

check:
	tl check src/xbeam-bp.tl

deploy:
	@if [ "$(filter vault,$(MAKECMDGOALS))" = "vault" ]; then \
		node scripts/vault/redeploy-vault.js; \
	else \
		echo "Usage: make deploy vault"; \
		exit 1; \
	fi

vault:
	@:
