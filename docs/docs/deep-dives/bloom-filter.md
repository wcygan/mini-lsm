---
sidebar_position: 4
---

# Bloom Filter

A Bloom filter is a **space-efficient probabilistic data structure** that answers "is this key possibly in this set?" - with a small chance of false positives but never false negatives.

## Overview

```mermaid
graph TB
    BF((Bloom Filter))

    BF --> PROPS((Properties))
    BF --> OPS((Operations))
    BF --> TRADEOFFS((Tradeoffs))

    PROPS --> P1((Probabilistic))
    PROPS --> P2((Space Efficient))
    PROPS --> P3((No Deletions))

    OPS --> O1((Add Key))
    OPS --> O2((Check Key))

    TRADEOFFS --> T1((False Positives))
    TRADEOFFS --> T2((No False Negatives))
    TRADEOFFS --> T3((Size vs Accuracy))

    style BF fill:#FFE4B5
```

## Why Bloom Filters?

In an LSM tree, a point lookup might need to check many SSTables. Without bloom filters:

```mermaid
graph TB
    subgraph Without["Without Bloom Filter"]
        GET1((Get Key)) --> SST1[Check SST 1]
        SST1 --> SST2[Check SST 2]
        SST2 --> SST3[Check SST 3]
        SST3 --> SST4[Check SST 4]
        SST4 --> FOUND1((Not Found))
    end

    subgraph With["With Bloom Filter"]
        GET2((Get Key)) --> BF1{Bloom 1}
        BF1 -->|No| BF2{Bloom 2}
        BF2 -->|No| BF3{Bloom 3}
        BF3 -->|Maybe| CHECK[Check SST 3]
        CHECK --> FOUND2((Not Found))
    end

    style SST1 fill:#FFB6C1
    style SST2 fill:#FFB6C1
    style SST3 fill:#FFB6C1
    style SST4 fill:#FFB6C1
    style BF1 fill:#98FB98
    style BF2 fill:#98FB98
    style CHECK fill:#FFE4B5
```

**Result**: 4 disk reads → 1 disk read (75% reduction)

## How It Works

A bloom filter is a bit array with multiple hash functions:

```mermaid
graph TB
    subgraph Add["Adding a Key"]
        KEY1((Key)) --> H1[Hash 1]
        KEY1 --> H2[Hash 2]
        KEY1 --> H3[Hash 3]
        H1 --> BIT1[Set bit 3]
        H2 --> BIT2[Set bit 7]
        H3 --> BIT3[Set bit 12]
    end

    subgraph Check["Checking a Key"]
        KEY2((Key)) --> H4[Hash 1]
        KEY2 --> H5[Hash 2]
        KEY2 --> H6[Hash 3]
        H4 --> C1{Bit 3 set?}
        H5 --> C2{Bit 7 set?}
        H6 --> C3{Bit 12 set?}
        C1 -->|Yes| C2
        C2 -->|Yes| C3
        C3 -->|Yes| MAYBE((Maybe Present))
        C1 -->|No| NO((Definitely Not))
        C2 -->|No| NO
        C3 -->|No| NO
    end

    style MAYBE fill:#FFE4B5
    style NO fill:#98FB98
```

## Code Example

From mini-lsm's Bloom filter implementation:

```rust
pub struct Bloom {
    /// Bit array storing the filter
    pub(crate) filter: Bytes,
    /// Number of hash functions (k)
    pub(crate) k: u8,
}

impl Bloom {
    /// Calculate optimal bits per key for a given false positive rate
    pub fn bloom_bits_per_key(entries: usize, false_positive_rate: f64) -> usize {
        let size = -1.0 * (entries as f64) * false_positive_rate.ln()
            / std::f64::consts::LN_2.powi(2);
        let locs = (size / (entries as f64)).ceil();
        locs as usize
    }

    /// Build a bloom filter from key hashes
    pub fn build_from_key_hashes(keys: &[u32], bits_per_key: usize) -> Self {
        // Calculate optimal number of hash functions
        // k = bits_per_key * ln(2) ≈ bits_per_key * 0.69
        let k = (bits_per_key as f64 * 0.69) as u32;
        let k = k.clamp(1, 30);

        // Allocate bit array
        let nbits = (keys.len() * bits_per_key).max(64);
        let nbytes = (nbits + 7) / 8;
        let nbits = nbytes * 8;
        let mut filter = BytesMut::zeroed(nbytes);

        // Add each key
        for h in keys {
            let mut h = *h;
            let delta = h.rotate_left(15); // Secondary hash

            for _ in 0..k {
                let bit_pos = (h as usize) % nbits;
                filter.set_bit(bit_pos, true);
                h = h.wrapping_add(delta);
            }
        }

        Self {
            filter: filter.freeze(),
            k: k as u8,
        }
    }

    /// Check if a key may be in the filter
    pub fn may_contain(&self, mut h: u32) -> bool {
        let nbits = self.filter.bit_len();
        let delta = h.rotate_left(15);

        for _ in 0..self.k {
            let bit_pos = h % (nbits as u32);
            if !self.filter.get_bit(bit_pos as usize) {
                return false; // Definitely not present
            }
            h = h.wrapping_add(delta);
        }
        true // Possibly present
    }
}

/// Bit manipulation helpers
pub trait BitSlice {
    fn get_bit(&self, idx: usize) -> bool;
}

impl<T: AsRef<[u8]>> BitSlice for T {
    fn get_bit(&self, idx: usize) -> bool {
        let pos = idx / 8;
        let offset = idx % 8;
        (self.as_ref()[pos] & (1 << offset)) != 0
    }
}
```

## False Positive Rate

The false positive rate depends on:
- **m**: number of bits in filter
- **n**: number of keys added
- **k**: number of hash functions

```
FPR ≈ (1 - e^(-kn/m))^k
```

```mermaid
graph TB
    FPR((False Positive Rate))

    FPR --> BITS((Bits per Key))
    FPR --> HASHES((Hash Functions))

    BITS --> B10["10 bits → ~1% FPR"]
    BITS --> B7["7 bits → ~3% FPR"]
    BITS --> B5["5 bits → ~10% FPR"]

    HASHES --> K7["k=7 optimal for 10 bits"]
    HASHES --> K5["k=5 optimal for 7 bits"]
    HASHES --> K3["k=3 optimal for 5 bits"]
```

## Configuration Guide

| Bits per Key | False Positive Rate | Memory per 1M Keys |
|--------------|--------------------|--------------------|
| 5 | ~10% | 625 KB |
| 7 | ~3% | 875 KB |
| 10 | ~1% | 1.25 MB |
| 15 | ~0.1% | 1.875 MB |
| 20 | ~0.01% | 2.5 MB |

## Integration with SSTable

```mermaid
graph TB
    subgraph Build["SSTable Build"]
        ADD[Add Keys] --> COLLECT[Collect Key Hashes]
        COLLECT --> BUILD[Build Bloom Filter]
        BUILD --> ENCODE[Encode to SSTable]
    end

    subgraph Query["SSTable Query"]
        GET[Get Key] --> HASH[Hash Key]
        HASH --> CHECK{Bloom Check}
        CHECK -->|No| SKIP[Skip SSTable]
        CHECK -->|Maybe| SEARCH[Search SSTable]
    end

    style SKIP fill:#98FB98
```

## Real-World Examples

### RocksDB

RocksDB's bloom filter options:
- **Full filter**: One filter for entire SSTable (default)
- **Partitioned filter**: Filter per data block (memory efficient)
- **Ribbon filter**: Newer, more space-efficient alternative
- **Prefix bloom**: Filter on key prefixes for prefix scans

### LevelDB

LevelDB uses a simple full-file bloom filter with configurable bits per key (default 10).

### Cassandra

Cassandra's bloom filters:
- Per-SSTable filters
- Configurable false positive rate per table
- Stored separately from data for faster loading
- Bloom filter statistics in system tables

### Redis

Redis uses bloom filters in the **RedisBloom module**:
- Scalable bloom filters (auto-grow)
- Counting bloom filters (support deletion)
- Cuckoo filters (alternative with deletion)

## Variants

```mermaid
graph TB
    BLOOM((Bloom Filter<br/>Variants))

    BLOOM --> STANDARD((Standard))
    BLOOM --> COUNTING((Counting))
    BLOOM --> SCALABLE((Scalable))
    BLOOM --> CUCKOO((Cuckoo))

    STANDARD --> S1((No delete))
    STANDARD --> S2((Fixed size))

    COUNTING --> C1((Supports delete))
    COUNTING --> C2((4x memory))

    SCALABLE --> SC1((Auto-grows))
    SCALABLE --> SC2((Multiple filters))

    CUCKOO --> CU1((Supports delete))
    CUCKOO --> CU2((Better space))
```

## Use Cases

| Use Case | Config | Why |
|----------|--------|-----|
| **Point lookups** | 10 bits, ~1% FPR | Good balance |
| **Range scans** | Prefix bloom | Filter on prefix |
| **Memory constrained** | 5 bits, ~10% FPR | Smaller filters |
| **Hot data** | 15+ bits, ~0.1% FPR | Minimize disk reads |

## Key Takeaways

1. **Bloom filters eliminate disk reads** - most "not found" cases skip I/O entirely
2. **No false negatives** - if bloom says "no", key definitely doesn't exist
3. **10 bits per key ≈ 1% FPR** - the sweet spot for most workloads
4. **Memory efficient** - ~1.25 MB per million keys at 1% FPR
5. **Can't delete** - standard bloom filters don't support removal
