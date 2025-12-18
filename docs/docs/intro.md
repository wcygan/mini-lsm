---
sidebar_position: 1
---

# Introduction to LSM Trees

A **Log-Structured Merge-tree (LSM tree)** is a data structure designed for high write throughput. It powers many modern databases and storage engines including RocksDB, LevelDB, Cassandra, and ScyllaDB.

## Why LSM Trees?

Traditional B-trees perform **random I/O** for every write—seeking to the correct page on disk and updating it in place. This becomes a bottleneck on both HDDs (slow seeks) and SSDs (write amplification from small random writes).

LSM trees solve this by converting random writes into **sequential writes**:

1. **Buffer writes in memory** (fast)
2. **Flush to disk sequentially** (efficient)
3. **Merge files in the background** (amortized cost)

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                        MEMORY                               │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐                                        │
│  │    MemTable     │  ← Active writes (skip list)           │
│  │   (mutable)     │                                        │
│  └─────────────────┘                                        │
│  ┌─────────────────┐                                        │
│  │  Immutable      │  ← Frozen, awaiting flush              │
│  │  MemTables      │                                        │
│  └─────────────────┘                                        │
├─────────────────────────────────────────────────────────────┤
│                         DISK                                │
├─────────────────────────────────────────────────────────────┤
│  Level 0 (L0):  [SST] [SST] [SST]    ← Unsorted, may overlap│
│                                                             │
│  Level 1 (L1):  [  SST  ] [  SST  ] [  SST  ]  ← Sorted     │
│                                                             │
│  Level 2 (L2):  [    SST    ] [    SST    ] [    SST    ]   │
│                                                             │
│  ...                                   (larger levels)      │
└─────────────────────────────────────────────────────────────┘
```

## Key Components

### MemTable

An in-memory data structure (typically a skip list or red-black tree) that buffers recent writes. When it reaches a size threshold, it becomes immutable and is scheduled for flushing to disk.

### SSTable (Sorted String Table)

An immutable, sorted file on disk containing key-value pairs. Each SSTable consists of:

- **Data blocks**: Sorted key-value pairs, compressed
- **Index block**: Maps key ranges to data blocks
- **Bloom filter**: Probabilistic structure to avoid unnecessary disk reads
- **Metadata**: First/last keys, timestamps, checksums

### Compaction

Background process that merges SSTables to:

- Remove deleted keys (tombstones)
- Eliminate duplicate versions of keys
- Maintain sorted order across levels
- Control space amplification

## Read & Write Paths

### Write Path

```
Put(key, value)
      │
      ▼
┌─────────────┐
│  Write to   │
│    WAL      │  ← Durability (crash recovery)
└─────────────┘
      │
      ▼
┌─────────────┐
│  Insert to  │
│  MemTable   │  ← In-memory, fast
└─────────────┘
      │
      ▼ (when full)
┌─────────────┐
│  Flush to   │
│   L0 SST    │  ← Sequential write to disk
└─────────────┘
```

### Read Path

```
Get(key)
      │
      ▼
┌─────────────┐
│  MemTable   │  ← Check newest data first
└─────────────┘
      │ miss
      ▼
┌─────────────┐
│  Immutable  │
│  MemTables  │
└─────────────┘
      │ miss
      ▼
┌─────────────┐
│   L0 SSTs   │  ← Check all (may overlap)
│ (use bloom) │
└─────────────┘
      │ miss
      ▼
┌─────────────┐
│  L1+ SSTs   │  ← Binary search (sorted, no overlap)
│ (use bloom) │
└─────────────┘
```

## Trade-offs

| Aspect | LSM Tree | B-Tree |
|--------|----------|--------|
| **Write throughput** | Excellent | Moderate |
| **Read latency** | Higher (multiple levels) | Lower (single tree) |
| **Space amplification** | Higher (temporary duplicates) | Lower |
| **Write amplification** | Higher (compaction rewrites) | Lower |

LSM trees excel when:
- Write-heavy workloads dominate
- Sequential disk access is preferred
- You can tolerate slightly higher read latency

## What You'll Build

In this course, you'll implement a complete LSM storage engine with:

- **Week 1**: Core structures (MemTable, Blocks, SSTables, Iterators)
- **Week 2**: Persistence (Compaction, WAL, Manifest)
- **Week 3**: Transactions (MVCC, Snapshots, Serializable Isolation)
