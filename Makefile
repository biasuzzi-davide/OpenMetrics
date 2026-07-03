.PHONY: app build run test clean package dmg dmg-from-app notarize

APP_NAME = OpenMetrics
APP_BUNDLE_ID = dev.davide.openmetrics
DIST_DIR = dist
APP_DIR = $(DIST_DIR)/$(APP_NAME).app
ZIP_PATH = $(DIST_DIR)/$(APP_NAME)-macOS.zip
DMG_STAGING_DIR = $(DIST_DIR)/dmg
DMG_PATH = $(DIST_DIR)/$(APP_NAME)-macOS.dmg
# Identità stabile: senza firma (adhoc) il keychain richiede la password a ogni build.
CODESIGN_ID ?= Apple Development
CODESIGN_FLAGS ?= --options runtime
DISTRIBUTION_CODESIGN_ID ?= Developer ID Application
NOTARY_PROFILE ?= openmetrics-notary

app: build
	mkdir -p "$(APP_DIR)/Contents/MacOS"
	cp ".build/release/$(APP_NAME)" "$(APP_DIR)/Contents/MacOS/$(APP_NAME)"
	cp Info.plist "$(APP_DIR)/Contents/Info.plist"
	chmod +x "$(APP_DIR)/Contents/MacOS/$(APP_NAME)"
	codesign --force --sign "$(CODESIGN_ID)" --identifier "$(APP_BUNDLE_ID)" $(CODESIGN_FLAGS) "$(APP_DIR)"

build:
	swift build -c release

run: app
	open "$(APP_DIR)"

test:
	swift test

package: CODESIGN_ID = $(DISTRIBUTION_CODESIGN_ID)
package: CODESIGN_FLAGS = --options runtime --timestamp
package: app
	codesign --verify --deep --strict --verbose=2 "$(APP_DIR)"
	rm -f "$(ZIP_PATH)"
	ditto -c -k --keepParent "$(APP_DIR)" "$(ZIP_PATH)"

dmg: CODESIGN_ID = -
dmg: CODESIGN_FLAGS = --options runtime
dmg: app dmg-from-app

dmg-from-app:
	rm -rf "$(DMG_STAGING_DIR)"
	mkdir -p "$(DMG_STAGING_DIR)"
	cp -R "$(APP_DIR)" "$(DMG_STAGING_DIR)/"
	ln -s /Applications "$(DMG_STAGING_DIR)/Applications"
	rm -f "$(DMG_PATH)"
	hdiutil create -volname "$(APP_NAME)" -srcfolder "$(DMG_STAGING_DIR)" -ov -format UDZO "$(DMG_PATH)"

notarize: package
	xcrun notarytool submit "$(ZIP_PATH)" --keychain-profile "$(NOTARY_PROFILE)" --wait
	xcrun stapler staple "$(APP_DIR)"
	xcrun stapler validate "$(APP_DIR)"
	rm -f "$(ZIP_PATH)"
	ditto -c -k --keepParent "$(APP_DIR)" "$(ZIP_PATH)"
	spctl -a -vv --type execute "$(APP_DIR)"

clean:
	rm -rf .build dist
