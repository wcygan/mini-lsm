# Mini-LSM task runner
set shell := ["bash", "-uc"]

# List available recipes
default:
    @just --list

# ─────────────────────────────────────────────────────────────────────────────
# Setup
# ─────────────────────────────────────────────────────────────────────────────

# Install development tools (run once)
install-tools:
    cargo x install-tools

# Copy test cases for a specific week and day
copy-test week day:
    cargo x copy-test --week {{ week }} --day {{ day }}

# ─────────────────────────────────────────────────────────────────────────────
# Development
# ─────────────────────────────────────────────────────────────────────────────

# Run checks on starter code
check:
    cargo x scheck

# Build starter crate
build:
    cargo build -p mini-lsm-starter

# Build in release mode
build-release:
    cargo build -p mini-lsm-starter --release

# Run all tests in starter crate
test *args:
    cargo test -p mini-lsm-starter {{ args }}

# Format code
fmt:
    cargo fmt

# Check formatting without modifying
fmt-check:
    cargo fmt --check

# Run clippy linter
lint:
    cargo clippy -p mini-lsm-starter -- -D warnings

# ─────────────────────────────────────────────────────────────────────────────
# CLI Tools
# ─────────────────────────────────────────────────────────────────────────────

# Run student CLI implementation
cli:
    cargo run --bin mini-lsm-cli

# Run reference CLI
cli-ref:
    cargo run --bin mini-lsm-cli-ref

# Run compaction simulator
compaction-sim:
    cargo run --bin compaction-simulator

# Run reference compaction simulator
compaction-sim-ref:
    cargo run --bin compaction-simulator-ref

# ─────────────────────────────────────────────────────────────────────────────
# CI / Maintainer
# ─────────────────────────────────────────────────────────────────────────────

# Full CI check (for maintainers)
ci:
    cargo x ci

# Sync starter repo with reference solution
sync:
    cargo x sync

# ─────────────────────────────────────────────────────────────────────────────
# Documentation (requires bun)
# ─────────────────────────────────────────────────────────────────────────────

# Start docs dev server
docs-dev:
    cd docs && bun start

# Build docs for production
docs-build:
    cd docs && bun run build

# Serve built docs locally
docs-serve:
    cd docs && bun run serve

# Install docs dependencies
docs-install:
    cd docs && bun install
