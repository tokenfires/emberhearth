# Makefile — EmberHearth convenience targets
# Usage: make [target]
#
# This Makefile is for DEVELOPER USE ONLY in the terminal.
# EmberHearth the application NEVER executes shell commands.

.PHONY: build test clean release security-check all check

# Default target
all: security-check build test

# Build the project (debug configuration)
build:
	@./build.sh build

# Run all tests
test:
	@./build.sh test

# Clean build artifacts
clean:
	@./build.sh clean

# Build release configuration
release:
	@./build.sh release

# Run security checks (no hardcoded keys, no shell execution in src/)
security-check:
	@./build.sh security-check

# Run everything: security check, build, and test
check: all
