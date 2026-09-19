APP_NAME := AltTabPersonal
BUILD    := build
APP      := $(BUILD)/$(APP_NAME).app
ARCH     := $(shell uname -m)
SOURCES  := $(wildcard Sources/*.swift)

.PHONY: app run clean

app: $(APP)

$(APP): $(SOURCES) Info.plist
	@mkdir -p $(APP)/Contents/MacOS $(APP)/Contents/Resources
	swiftc -O -target $(ARCH)-apple-macos14.0 \
		-o $(APP)/Contents/MacOS/$(APP_NAME) \
		$(SOURCES) \
		-framework AppKit -framework ApplicationServices
	@cp Info.plist $(APP)/Contents/Info.plist
	@codesign --force --sign - $(APP) 2>/dev/null || true
	@echo "Hazır: $(APP)"

run: app
	open $(APP)

clean:
	rm -rf $(BUILD)
