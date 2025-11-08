.PHONY: build clean install test help

BINARY_NAME=macos-agent
BUILD_DIR=.build
INSTALL_PATH=/usr/local/bin

help:
	@echo "MacOS Agent CLI - Build Commands"
	@echo ""
	@echo "  make build    - Build the CLI tool"
	@echo "  make release  - Build optimized release binary"
	@echo "  make install  - Install to $(INSTALL_PATH)"
	@echo "  make clean    - Clean build artifacts"
	@echo "  make test     - Run a test snapshot"
	@echo ""

build:
	swift build

release:
	swift build -c release

install: release
	cp $(BUILD_DIR)/release/$(BINARY_NAME) $(INSTALL_PATH)/$(BINARY_NAME)
	@echo "Installed to $(INSTALL_PATH)/$(BINARY_NAME)"

clean:
	swift package clean
	rm -rf $(BUILD_DIR)

test: build
	@echo "Running test snapshot..."
	$(BUILD_DIR)/debug/$(BINARY_NAME) snapshot
