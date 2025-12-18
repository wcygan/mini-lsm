---
sidebar_position: 2
---

# LSM Tree Architecture

This diagram illustrates the structure and data flow of an LSM (Log-Structured Merge-tree) storage engine.

## LSM Tree Structure

The LSM tree organizes data hierarchically from fast memory to persistent disk storage:

```mermaid
graph TB
    LSM((LSM Tree))

    LSM --> MEM((Memory))
    LSM --> DISK((Disk))

    MEM --> WAL((WAL))
    MEM --> MT((MemTable))
    MEM --> IMT((Immutable<br/>MemTables))

    DISK --> L0((Level 0))
    DISK --> L1((Level 1))
    DISK --> L2((Level 2))
    DISK --> LN((Level N))

    L0 --> L0_1((SST))
    L0 --> L0_2((SST))
    L0 --> L0_3((SST))

    L1 --> L1_1((SST))
    L1 --> L1_2((SST))

    L2 --> L2_1((SST))
    L2 --> L2_2((SST))
    L2 --> L2_3((SST))
    L2 --> L2_4((SST))
```

## Data Flow Tree

Shows how data flows through the LSM tree from writes to compacted storage:

```mermaid
graph TB
    W((Write)) --> WAL((WAL))
    WAL --> MT((MemTable))
    MT -->|full| IMT((Immutable))
    IMT -->|flush| L0((L0 SSTs))
    L0 -->|compact| L1((L1 SSTs))
    L1 -->|compact| L2((L2 SSTs))
    L2 -->|compact| LN((LN SSTs))

    style W fill:#90EE90
    style WAL fill:#FFB6C1
    style MT fill:#87CEEB
    style IMT fill:#87CEEB
    style L0 fill:#DDA0DD
    style L1 fill:#DDA0DD
    style L2 fill:#DDA0DD
    style LN fill:#DDA0DD
```

## SSTable Internal Structure

Each SSTable is organized as a tree of blocks:

```mermaid
graph TB
    SST((SSTable))

    SST --> DATA((Data<br/>Blocks))
    SST --> IDX((Index<br/>Block))
    SST --> BF((Bloom<br/>Filter))
    SST --> META((Metadata))

    DATA --> B1((Block 1))
    DATA --> B2((Block 2))
    DATA --> B3((Block 3))

    B1 --> KV1((k1:v1))
    B1 --> KV2((k2:v2))
    B1 --> KV3((k3:v3))

    B2 --> KV4((k4:v4))
    B2 --> KV5((k5:v5))

    B3 --> KV6((k6:v6))
    B3 --> KV7((k7:v7))
    B3 --> KV8((k8:v8))
```

## Read Path Tree

The search traverses the tree from newest to oldest data:

```mermaid
graph TB
    GET((Get Key))

    GET --> MT((MemTable))
    MT -->|miss| IMT((Immutable<br/>MemTables))
    IMT -->|miss| L0((Level 0))
    L0 -->|miss| L1((Level 1))
    L1 -->|miss| L2((Level 2))

    MT -->|hit| FOUND((Found))
    IMT -->|hit| FOUND
    L0 -->|hit| FOUND
    L1 -->|hit| FOUND
    L2 -->|hit| FOUND
    L2 -->|miss| NOTFOUND((Not Found))

    style GET fill:#90EE90
    style FOUND fill:#98FB98
    style NOTFOUND fill:#FFB6C1
```

## Compaction Tree

Compaction merges overlapping SSTables into sorted, non-overlapping files:

```mermaid
graph TB
    COMPACT((Compaction))

    COMPACT --> INPUT((Input))
    COMPACT --> OUTPUT((Output))

    INPUT --> L0A((L0 SST<br/>a,b,c))
    INPUT --> L0B((L0 SST<br/>b,d,e))
    INPUT --> L1A((L1 SST<br/>a,b))
    INPUT --> L1B((L1 SST<br/>c,d,e,f))

    OUTPUT --> NEW1((L1 SST<br/>a,b,c))
    OUTPUT --> NEW2((L1 SST<br/>d,e,f))

    style INPUT fill:#FFB6C1
    style OUTPUT fill:#98FB98
```

## Level Size Tree

Each level grows exponentially larger (typically 10x):

```mermaid
graph TB
    LEVELS((Disk Levels))

    LEVELS --> L0((L0<br/>~64MB))
    LEVELS --> L1((L1<br/>~640MB))
    LEVELS --> L2((L2<br/>~6.4GB))
    LEVELS --> L3((L3<br/>~64GB))

    L0 --> L0N((4 SSTs))
    L1 --> L1N((10 SSTs))
    L2 --> L2N((100 SSTs))
    L3 --> L3N((1000 SSTs))
```

## Key Concepts

| Component | Purpose |
|-----------|---------|
| **MemTable** | Fast in-memory writes using skip list |
| **WAL** | Durability - recover data after crash |
| **SSTable** | Immutable sorted file on disk |
| **Bloom Filter** | Skip SSTs that definitely don't contain a key |
| **Compaction** | Merge SSTables, remove duplicates and tombstones |
