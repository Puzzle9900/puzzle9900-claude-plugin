---
name: generic-cache-eviction
description: Guide implementing TTR-based in-memory cache eviction with clock-safe time comparison and deployment jitter
type: generic
---

# generic-cache-eviction

## Context
Any time a cache mechanism is created, it **must** include eviction. This skill enforces a consistent, clock-safe TTR (time-to-refresh) eviction strategy for in-memory caches. It applies across all platforms (Android, iOS, backend, web).

## Instructions

You are a cache implementation reviewer and guide. When invoked, walk the developer through building eviction correctly for their cache.

---

## Step 1 — Ask Required Questions

Before writing any code, ask the developer:

1. **Default TTR**: What is the default time-to-refresh for this cache?
   - Suggest common tiers if they are unsure: `5m`, `15m`, `1h`, `24h`
   - This value is **required** — do not proceed without it

2. **Size limit** *(optional, recommend asking)*: Should the cache have a max entry count?
   - Explain: size limits prevent unbounded memory growth in long-running processes
   - If yes, ask for the limit and note that eviction should apply on both TTR expiry **and** when the limit is reached (evict oldest or least-recently-used entry)
   - If no, proceed without size enforcement

---

## Step 2 — Implement Clock-Safe TTR Check

### The Problem with Raw Time Differences
Do **not** use:
```
currentTime - storedTime > TTR   // breaks if clock moves backward (negative result)
```

### The Correct Approach: Absolute Value
Always use the absolute value of the time difference to handle:
- Normal forward progression
- NTP corrections (small adjustments, no false eviction)
- User manually setting clock forward (large delta → evict, safe)
- User manually setting clock backward (large delta → evict, safe — better to refresh than serve stale)

```
elapsed = abs(currentTime - storedTimestamp)
isExpired = elapsed >= effectiveTTR
```

**effectiveTTR** = `TTR + jitter` (see Step 3)

### What Clock Source to Use
Always use the **user device time** (wall clock as set by the user). Reasoning:
- Process uptime clocks reset on restart — can cause premature or skipped eviction
- NTP time may differ from device time and creates inconsistency for the user
- The user's device clock is what governs their perception of time; eviction should align with it
- With absolute value comparison, backward adjustments are handled safely

---

## Step 3 — Add Jitter

Jitter prevents a deployment (or a batch of cold starts) from expiring all cache entries simultaneously, causing a thundering herd of refreshes.

### Rules
- Jitter is computed **once at write time** and stored alongside the cached value
- Jitter is drawn from a **uniform distribution** over `[0, jitterMax]`
- Default `jitterMax`: **5 minutes** (adjust if TTR is very short, e.g., use `TTR * 0.1` if TTR < 10m)
- Jitter always **adds** to TTR (never subtracts) — this avoids early eviction

```
jitter = random_uniform(0, jitterMax)        // computed once, stored at write time
effectiveTTR = TTR + jitter

// At write:
entry = { value, storedTimestamp: now(), effectiveTTR }

// At read:
elapsed = abs(now() - entry.storedTimestamp)
if elapsed >= entry.effectiveTTR:
    evict and refresh
```

---

## Step 4 — Cache Entry Structure

Every cache entry must carry at minimum:

```
CacheEntry {
  value:           <cached data>
  storedTimestamp: <device wall clock at write time>
  effectiveTTR:    <TTR + jitter, computed at write time>
}
```

If size limit is enabled, also track:
```
  lastAccessedAt:  <timestamp of last read, for LRU eviction>
```

---

## Step 5 — Eviction Trigger Points

Check eviction at **read time** (lazy eviction). Do not run background sweeps unless the cache is long-lived and can grow unboundedly.

```
function get(key):
  entry = store[key]
  if entry is null:
    return MISS

  elapsed = abs(now() - entry.storedTimestamp)
  if elapsed >= entry.effectiveTTR:
    store.remove(key)
    return MISS   // caller fetches fresh value and calls put()

  return entry.value


function put(key, value, ttr, jitterMax = 5min):
  jitter = random_uniform(0, jitterMax)
  store[key] = CacheEntry(
    value           = value,
    storedTimestamp = now(),
    effectiveTTR    = ttr + jitter
  )
```

If size limit is enabled, after `put()`:
```
  if store.size > maxEntries:
    evict entry with the smallest lastAccessedAt (LRU)
```

---

## Step 6 — Verification Checklist

Before considering the cache implementation complete, confirm:

- [ ] Every cache entry stores `storedTimestamp` and `effectiveTTR`
- [ ] Eviction uses `abs(now() - storedTimestamp) >= effectiveTTR`
- [ ] Jitter is computed at **write time** from a uniform distribution `[0, jitterMax]`
- [ ] Default TTR is documented and configurable
- [ ] Clock source is device wall clock (not process uptime, not monotonic clock)
- [ ] If size limit: LRU eviction is applied when limit is exceeded
- [ ] Cache miss path always triggers a fresh fetch and re-population

---

## Constraints
- Never use raw (signed) time differences for expiry comparison
- Never compute jitter at read time — it must be fixed per entry at write time
- Do not use process uptime or monotonic clocks as the time source for TTR
- Always document the default TTR value in the cache class or module
- Platform-agnostic — translate `abs()`, `random_uniform()`, and `now()` to the target language's standard library
