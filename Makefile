.PHONY: build-macos test-macos clean-macos build-linux test-linux run-linux-daemon ci
# Arch install note:
#   sudo pacman -S swift pipewire wireplumber wl-clipboard wtype ollama
#   Install whisper.cpp runtime/libs so whisper.h and libwhisper/libggml* are available.

build-macos:
	cd apps/dictator-main && swift build

test-macos:
	cd apps/dictator-main && swift test

clean-macos:
	cd apps/dictator-main && swift package clean

build-linux:
	cd apps/dictator-main && swift build --product dictator-linux

test-linux:
	cd apps/dictator-main && swift test --filter DictatorLinuxTests

run-linux-daemon:
	cd apps/dictator-main && swift run dictator-linux daemon

ci: test-macos
