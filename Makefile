# Modernized Makefile for Nally (macOS Telnet/SSH BBS Client)

XCODEBUILD   ?= xcodebuild
SCHEME       ?= Nally
TEST_SCHEME  ?= TextSuiteTests
CONFIG       ?= Release
SYMROOT      ?= $(CURDIR)/build
DERIVED_DATA ?= $(CURDIR)/build/DerivedData

.PHONY: all clean test install release help

all:
	$(XCODEBUILD) -scheme $(SCHEME) -configuration $(CONFIG) SYMROOT="$(SYMROOT)" -derivedDataPath "$(DERIVED_DATA)" build

clean:
	@echo "Cleaning Nally build artifacts..."
	@rm -rf "$(SYMROOT)"
	@rm -f Nally.xcodeproj/project.xcworkspace/xcuserdata/* 2>/dev/null || true
	@rm -f Nally.xcodeproj/xcuserdata/* 2>/dev/null || true
	@rm -f Nally.xcodeproj/*.mode1v3 Nally.xcodeproj/*.pbxuser 2>/dev/null || true
	@echo "Clean completed."

test:
	@echo "Running Nally test suites..."
	$(XCODEBUILD) test -scheme $(TEST_SCHEME) -configuration $(CONFIG) SYMROOT="$(SYMROOT)" -derivedDataPath "$(DERIVED_DATA)"

install: all
	@echo "Installing Nally.app to /Applications..."
	@rm -rf /Applications/Nally.app
	@cp -R "$(SYMROOT)/$(CONFIG)/Nally.app" /Applications/
	@echo "Nally.app installed successfully."

release: all
	@echo "Packaging Nally release..."
	python3 Scripts/package.py "$(SYMROOT)/$(CONFIG)/Nally.app" http://nally.googlecode.com/files 2>/dev/null || \
	python Scripts/package.py "$(SYMROOT)/$(CONFIG)/Nally.app" http://nally.googlecode.com/files

help:
	@echo "Available make targets for Nally:"
	@echo "  all      - Build Nally.app in Release configuration (default target)"
	@echo "  clean    - Remove build artifacts and derived data cache"
	@echo "  test     - Execute unit test suite (26 tests across 9 test suites)"
	@echo "  install  - Build and install Nally.app to /Applications"
	@echo "  release  - Package Nally.app for distribution"
