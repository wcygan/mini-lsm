# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Mini-LSM is a tutorial project for building an LSM (Log-Structured Merge-tree) storage engine in Rust. It's a 3-week course where students implement a key-value storage engine incrementally.

## Crate Structure

- **mini-lsm-starter**: Where students write their code (main development target)
- **mini-lsm**: Reference solution for weeks 1-2
- **mini-lsm-mvcc**: Reference solution for week 3 (MVCC)
- **xtask**: Build automation and course tooling

## Common Commands

```bash
# Install development tools (run once)
cargo x install-tools

# Copy test cases for a specific day (enables tests incrementally)
cargo x copy-test --week 1 --day 1

# Run checks on starter code
cargo x scheck

# Run reference CLI for testing
cargo run --bin mini-lsm-cli-ref
cargo run --bin compaction-simulator-ref

# Run student implementation
cargo run --bin mini-lsm-cli

# Full CI check (for maintainers)
cargo x ci
```

## Running Tests

Tests are copied incrementally per day. After copying tests for a day:

```bash
# Run all tests in starter crate
cargo test -p mini-lsm-starter

# Run specific test
cargo test -p mini-lsm-starter test_name
```

## Architecture

### Core Data Flow

```
Put/Delete → MemTable (skip list) → Immutable MemTables → SST Files → Compaction
```

### Key Components (mini-lsm-starter/src/)

**Storage Layer:**
- `block.rs` - Smallest unit of storage; sorted key-value pairs with `BlockBuilder`/`BlockIterator`
- `table.rs` - SSTable (Sorted String Table); contains blocks + metadata + bloom filter
- `mem_table.rs` - In-memory skip list for recent writes

**Iterator Hierarchy:**
- `iterators/` - `StorageIterator` trait with `MergeIterator`, `TwoMergeIterator`, `ConcatIterator`
- `lsm_iterator.rs` - Top-level iterator combining memtables and SSTs

**Engine Core:**
- `lsm_storage.rs` - Main `MiniLsm` struct managing state, memtables, SSTs
- `compact/` - Compaction strategies: Simple, Leveled (RocksDB-style), Tiered (Universal)

**Persistence:**
- `manifest.rs` - Metadata persistence for recovery
- `wal.rs` - Write-ahead log for durability

**MVCC (Week 3):**
- `mvcc/` - Multi-version concurrency control with timestamps, watermarks, transactions

### State Management

`LsmStorageState` holds:
- Active memtable + immutable memtables
- L0 SSTs (unsorted, newest first)
- Leveled SSTs (`levels` field) - organized by compaction strategy

### Key Abstractions

- `KeySlice`/`KeyBytes` - Keys with optional timestamps (week 3)
- `BlockCache` - LRU cache for SST blocks using `moka`
- `CompactionController` - Pluggable compaction strategies

## Course Progression

Week 1: Memtable → Iterators → Block → SST → Read/Write paths → Bloom filters
Week 2: Compaction strategies → Manifest → WAL → Batch writes
Week 3: Timestamps → Snapshots → Transactions → OCC → Serializable isolation
