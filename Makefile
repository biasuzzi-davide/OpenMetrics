.PHONY: app build run test clean

APP_NAME = OpenMetrics
APP_DIR = dist/$(APP_NAME).app
# Identità stabile: senza firma (adhoc) il keychain richiede la password a ogni build.
CODESIGN_ID ?= Apple Development

app: build
	mkdir -p "$(APP_DIR)/Contents/MacOS"
	cp ".build/release/$(APP_NAME)" "$(APP_DIR)/Contents/MacOS/$(APP_NAME)"
	cp Info.plist "$(APP_DIR)/Contents/Info.plist"
	chmod +x "$(APP_DIR)/Contents/MacOS/$(APP_NAME)"
	codesign --force --sign "$(CODESIGN_ID)" --identifier dev.davide.openmetrics --options runtime "$(APP_DIR)"

build:
	swift build -c release

run: app
	open "$(APP_DIR)"

test:
	swift test

clean:
	rm -rf .build dist
