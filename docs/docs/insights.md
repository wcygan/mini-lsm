---
sidebar_position: 3
---

# Key Insights & Applications

Understanding why LSM trees work and where they excel helps you make informed architectural decisions.

## Core Insights

### 1. Sequential Writes Beat Random Writes

The fundamental insight behind LSM trees: **sequential I/O is dramatically faster than random I/O**.

```mermaid
graph LR
    subgraph Random["Random Writes (B-Tree)"]
        R1((Seek)) --> R2((Write)) --> R3((Seek)) --> R4((Write))
    end

    subgraph Sequential["Sequential Writes (LSM)"]
        S1((Write)) --> S2((Write)) --> S3((Write)) --> S4((Write))
    end
```

| Storage Type | Random Write | Sequential Write | Ratio |
|--------------|--------------|------------------|-------|
| HDD | ~100 IOPS | ~100 MB/s | 1000x |
| SSD | ~10K IOPS | ~500 MB/s | 50x |
| NVMe | ~100K IOPS | ~3 GB/s | 30x |

Even on fast NVMe drives, sequential writes provide significant advantages.

### 2. Trade Write Amplification for Write Throughput

LSM trees accept **write amplification** (data written multiple times during compaction) in exchange for high write throughput:

```mermaid
graph TB
    TRADEOFF((LSM Tradeoffs))

    TRADEOFF --> GAIN((Gains))
    TRADEOFF --> COST((Costs))

    GAIN --> G1((High Write<br/>Throughput))
    GAIN --> G2((Sequential<br/>I/O))
    GAIN --> G3((Efficient<br/>Compression))

    COST --> C1((Write<br/>Amplification))
    COST --> C2((Space<br/>Amplification))
    COST --> C3((Read<br/>Amplification))

    style GAIN fill:#98FB98
    style COST fill:#FFB6C1
```

**Write Amplification**: Data may be written 10-30x over its lifetime as it moves through levels.

**Space Amplification**: Temporary duplicate keys exist until compaction removes them.

**Read Amplification**: Reads may check multiple levels before finding a key.

### 3. Immutability Enables Concurrency

SSTable immutability provides powerful guarantees:

```mermaid
graph TB
    IMMUTABLE((Immutable SSTables))

    IMMUTABLE --> LOCK((Lock-Free<br/>Reads))
    IMMUTABLE --> CACHE((Safe to<br/>Cache))
    IMMUTABLE --> SNAP((Point-in-Time<br/>Snapshots))
    IMMUTABLE --> REP((Easy<br/>Replication))

    style IMMUTABLE fill:#87CEEB
```

- **No read locks needed** - readers never conflict with writers
- **Cache-friendly** - SSTable blocks never change after creation
- **Snapshots are cheap** - just retain old SSTables
- **Replication is simple** - ship immutable files to replicas

### 4. Bloom Filters Are Essential

Without bloom filters, reads would be prohibitively slow:

```mermaid
graph TB
    READ((Read Key))

    READ --> BF{Bloom Filter}
    BF -->|Negative| SKIP((Skip SSTable<br/>~99% of cases))
    BF -->|Positive| CHECK((Check SSTable<br/>~1% of cases))

    style SKIP fill:#98FB98
    style CHECK fill:#FFE4B5
```

A bloom filter with 10 bits per key achieves ~1% false positive rate, eliminating most unnecessary disk reads.

### 5. Compaction Strategy Matters

Different workloads benefit from different compaction strategies:

```mermaid
graph TB
    COMPACT((Compaction<br/>Strategies))

    COMPACT --> LEVEL((Leveled))
    COMPACT --> TIER((Tiered))
    COMPACT --> FIFO((FIFO))

    LEVEL --> L1((Low Space Amp))
    LEVEL --> L2((Higher Write Amp))
    LEVEL --> L3((Good for Reads))

    TIER --> T1((Low Write Amp))
    TIER --> T2((Higher Space Amp))
    TIER --> T3((Good for Writes))

    FIFO --> F1((No Compaction))
    FIFO --> F2((Time-Series Data))
    FIFO --> F3((TTL Expiration))
```

## Real-World Applications

### Databases Using LSM Trees

```mermaid
graph TB
    LSM((LSM-Based<br/>Systems))

    LSM --> KV((Key-Value<br/>Stores))
    LSM --> WIDE((Wide-Column<br/>Stores))
    LSM --> DOC((Document<br/>Stores))
    LSM --> TS((Time-Series<br/>Databases))

    KV --> RDB((RocksDB))
    KV --> LDB((LevelDB))
    KV --> PEBBLE((Pebble))

    WIDE --> CASS((Cassandra))
    WIDE --> SCYLLA((ScyllaDB))
    WIDE --> HBASE((HBase))

    DOC --> MONGO((MongoDB<br/>WiredTiger))
    DOC --> COUCH((CouchDB))

    TS --> INFLUX((InfluxDB))
    TS --> VICTORIA((VictoriaMetrics))
```

### Use Case Fit

| Use Case | LSM Fit | Why |
|----------|---------|-----|
| **Write-heavy OLTP** | Excellent | High write throughput |
| **Time-series data** | Excellent | Append-mostly, sequential |
| **Event logging** | Excellent | Write-once, read-rarely |
| **Message queues** | Good | Sequential writes, FIFO reads |
| **Caching layer** | Good | Fast writes, TTL support |
| **Read-heavy OLTP** | Moderate | Read amplification overhead |
| **OLAP / Analytics** | Poor | Full scans across levels |
| **Small datasets** | Poor | Overhead not worth it |

## When to Choose LSM Trees

### Ideal Workloads

```mermaid
graph TB
    IDEAL((Ideal for LSM))

    IDEAL --> W1((Write-Heavy<br/>Workloads))
    IDEAL --> W2((Append-Mostly<br/>Patterns))
    IDEAL --> W3((Point Lookups<br/>by Key))
    IDEAL --> W4((Range Scans<br/>on Hot Data))

    style IDEAL fill:#98FB98
```

**Best when:**
- Write throughput is critical
- Data is written once, read occasionally
- Keys have good locality (range queries benefit)
- You can tolerate slightly higher read latency

### Avoid When

```mermaid
graph TB
    AVOID((Avoid LSM When))

    AVOID --> A1((Heavy Random<br/>Reads))
    AVOID --> A2((Frequent<br/>Updates))
    AVOID --> A3((Complex<br/>Queries))
    AVOID --> A4((Strict Latency<br/>SLAs))

    style AVOID fill:#FFB6C1
```

**Not ideal when:**
- Read latency must be consistently low
- Same keys are updated frequently (high write amp)
- You need complex secondary indexes
- Dataset fits in memory anyway

## Performance Characteristics

### Complexity Analysis

| Operation | Average | Worst Case |
|-----------|---------|------------|
| Write | O(1) | O(1) |
| Point Read | O(log N) | O(L * log N) |
| Range Scan | O(log N + K) | O(L * log N + K) |
| Delete | O(1) | O(1) |

Where:
- **N** = total number of keys
- **L** = number of levels
- **K** = number of keys in range

### Memory vs Disk Tradeoffs

```mermaid
graph TB
    CONFIG((Configuration<br/>Choices))

    CONFIG --> MEM((More Memory))
    CONFIG --> DISK((More Disk))

    MEM --> M1((Larger MemTable))
    MEM --> M2((Bigger Block Cache))
    MEM --> M3((Bloom Filters))

    DISK --> D1((More Levels))
    DISK --> D2((Less Compaction))
    DISK --> D3((Higher Read Amp))

    M1 --> RESULT1((Fewer Flushes))
    M2 --> RESULT2((Cached Reads))
    M3 --> RESULT3((Skip Disk Reads))

    style MEM fill:#98FB98
    style DISK fill:#FFE4B5
```

## Key Takeaways

1. **LSM trees optimize for write throughput** by converting random writes to sequential
2. **Immutability is a feature** - enables lock-free reads, easy snapshots, simple replication
3. **Bloom filters are critical** - without them, read performance would be unacceptable
4. **Choose your compaction strategy** based on your read/write ratio
5. **LSM trees shine for write-heavy, append-mostly workloads** - not for everything
