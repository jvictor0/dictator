.PHONY: build-macos test-macos ci

build-macos:
	cd apps/macos-client && swift build

test-macos:
	cd apps/macos-client && swift test

ci: test-macos
