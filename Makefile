# ClipMate — Makefile-driven build (Command Line Tools only; no Xcode needed).
#
#   make           # build ClipMate.app into build/
#   make run       # build + launch
#   make install   # build + copy to /Applications
#   make clean

APP_NAME := ClipMate
BUILD_DIR := build
APP_BUNDLE := $(BUILD_DIR)/$(APP_NAME).app
CONTENTS := $(APP_BUNDLE)/Contents
MACOS_DIR := $(CONTENTS)/MacOS
RES_DIR := $(CONTENTS)/Resources
BIN := $(MACOS_DIR)/$(APP_NAME)

SWIFT_SOURCES := $(wildcard Sources/*.swift)

SDK := $(shell xcrun --show-sdk-path --sdk macosx)
TARGET := arm64-apple-macos14.0

SWIFTC_FLAGS := \
	-O \
	-sdk $(SDK) \
	-target $(TARGET) \
	-framework AppKit \
	-framework SwiftUI \
	-framework Combine \
	-framework Carbon

.PHONY: all run install clean codesign dirs

all: dirs $(BIN) $(CONTENTS)/Info.plist
	@echo "→ Built $(APP_BUNDLE)"

dirs:
	@mkdir -p $(MACOS_DIR) $(RES_DIR)

$(BIN): $(SWIFT_SOURCES)
	@echo "→ Compiling $(APP_NAME)…"
	swiftc $(SWIFTC_FLAGS) -o $(BIN) $(SWIFT_SOURCES)
	@$(MAKE) --no-print-directory codesign

$(CONTENTS)/Info.plist: Info.plist
	@cp Info.plist $(CONTENTS)/Info.plist

codesign:
	@codesign --force --deep --sign - $(APP_BUNDLE) >/dev/null 2>&1 || true
	@echo "→ ad-hoc signed."

run: all
	@echo "→ Launching $(APP_NAME)…"
	@/usr/bin/open $(APP_BUNDLE)

install: all
	@echo "→ Installing to /Applications/$(APP_NAME).app"
	@rm -rf /Applications/$(APP_NAME).app
	@cp -R $(APP_BUNDLE) /Applications/

clean:
	rm -rf $(BUILD_DIR)
