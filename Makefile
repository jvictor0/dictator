.PHONY: build-macos test-macos clean-macos ci

build-macos:
	cd apps/dictator-main && swift build

test-macos:
	cd apps/dictator-main && swift test

clean-macos:
	cd apps/dictator-main && swift package clean

ci: test-macos
