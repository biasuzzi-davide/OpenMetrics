.PHONY: app build run test clean

APP_NAME = OpenMetrics
APP_DIR = dist/$(APP_NAME).app

app: build
	mkdir -p "$(APP_DIR)/Contents/MacOS"
	cp ".build/release/$(APP_NAME)" "$(APP_DIR)/Contents/MacOS/$(APP_NAME)"
	cp Info.plist "$(APP_DIR)/Contents/Info.plist"
	chmod +x "$(APP_DIR)/Contents/MacOS/$(APP_NAME)"

build:
	swift build -c release

run: app
	open "$(APP_DIR)"

test:
	swift test

clean:
	rm -rf .build dist
