.PHONY: build test fmt lint clean bindings

build:
	stellar contract build

test:
	cargo test

fmt:
	cargo fmt --all

lint:
	cargo clippy --all-targets -- -D warnings

clean:
	cargo clean

bindings:
	stellar contract bindings typescript --wasm target/wasm32v1-none/release/aidline.wasm --output-dir packages/aidline-bindings --overwrite
