# Mnemo — Makefile-driven build (Command Line Tools only; no Xcode needed).
#
#   make           # build Mnemo.app into build/
#   make run       # build + launch
#   make install   # build + copy to /Applications
#   make clean

APP_NAME := Mnemo
BUILD_DIR := build
APP_BUNDLE := $(BUILD_DIR)/$(APP_NAME).app
CONTENTS := $(APP_BUNDLE)/Contents
MACOS_DIR := $(CONTENTS)/MacOS
RES_DIR := $(CONTENTS)/Resources
FRAMEWORKS_DIR := $(CONTENTS)/Frameworks
BIN := $(MACOS_DIR)/$(APP_NAME)

SWIFT_SOURCES := $(wildcard Sources/*.swift)

SDK := $(shell xcrun --show-sdk-path --sdk macosx)
TARGET := arm64-apple-macos14.0

SPARKLE_FRAMEWORK := Frameworks/Sparkle.framework

SWIFTC_FLAGS := \
	-O \
	-sdk $(SDK) \
	-target $(TARGET) \
	-F Frameworks \
	-framework AppKit \
	-framework SwiftUI \
	-framework Combine \
	-framework Carbon \
	-framework Sparkle \
	-Xlinker -rpath -Xlinker @executable_path/../Frameworks

.PHONY: all run install clean codesign dirs dmg sparkle

all: dirs sparkle $(BIN) $(CONTENTS)/Info.plist $(RES_DIR)/AppIcon.icns $(FRAMEWORKS_DIR)/Sparkle.framework
	@$(MAKE) --no-print-directory codesign
	@echo "→ Built $(APP_BUNDLE)"

dirs:
	@mkdir -p $(MACOS_DIR) $(RES_DIR) $(FRAMEWORKS_DIR)

sparkle: $(SPARKLE_FRAMEWORK)

$(SPARKLE_FRAMEWORK):
	@echo "→ Fetching Sparkle framework…"
	@bash scripts/fetch-sparkle.sh

$(BIN): $(SWIFT_SOURCES) $(SPARKLE_FRAMEWORK)
	@echo "→ Compiling $(APP_NAME)…"
	swiftc $(SWIFTC_FLAGS) -o $(BIN) $(SWIFT_SOURCES)

$(CONTENTS)/Info.plist: Info.plist
	@cp Info.plist $(CONTENTS)/Info.plist

$(RES_DIR)/AppIcon.icns: Resources/AppIcon.icns
	@cp Resources/AppIcon.icns $(RES_DIR)/AppIcon.icns

$(FRAMEWORKS_DIR)/Sparkle.framework: $(SPARKLE_FRAMEWORK)
	@echo "→ Embedding Sparkle.framework…"
	@rm -rf $(FRAMEWORKS_DIR)/Sparkle.framework
	@cp -R $(SPARKLE_FRAMEWORK) $(FRAMEWORKS_DIR)/Sparkle.framework

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

dmg: all
	@echo "→ Building DMG…"
	@bash scripts/make-dmg.sh
