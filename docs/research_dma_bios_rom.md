# Research: DMA, BIOS Protection, ROM, and Open Bus Failures

## Overview

Approximately 176+ tests fail across the mGBA test suite's **Memory tests** and **DMA tests** sections due to three related missing features:

1. **No DMA internal latch** -- DMA reads from inaccessible regions return 0 instead of the last value the DMA unit successfully read.
2. **No BIOS read protection** -- the CPU and DMA can read raw BIOS data from any context, instead of returning the "last BIOS fetch" latch value when PC is outside BIOS.
3. **No CPU open bus value** -- reads from unmapped address ranges (0x10000000+, region 0x1, etc.) return 0 instead of the last prefetched opcode.

These three mechanisms are all "latch" behaviors: hardware retains the last value from a prior access and returns it when a new read is invalid or protected.

---

## 1. DMA Internal Latch

### What gbatek documents

The GBA DMA unit has an internal read latch (one per bus width -- 16-bit and 32-bit are separate). When DMA performs a transfer, each read updates this latch with the value read from the source. When a DMA read hits an unmapped or inaccessible address (BIOS when protected, address > 0x0FFFFFFF, SRAM with wrong width, etc.), the latch retains its previous value and that value is written to the destination.

Key behaviors:
- The latch is shared across all 4 DMA channels.
- There are two latches: one for 16-bit (halfword) transfers and one for 32-bit (word) transfers.
- On GBA power-on, both latches are 0.
- Each successful DMA read updates the appropriate latch.
- When DMA reads from an invalid/inaccessible source, the old latch value is written to the destination.

### What the emulator currently does

**File:** `src/dingbat/gba/dma.nim`, lines 107-113

```nim
for _ in 0 ..< len:
  if word_size == 4:
    dma.gba.bus.write_word(dma.dst[channel], dma.gba.bus.read_word(dma.src[channel]))
  else:
    dma.gba.bus.write_half(dma.dst[channel], dma.gba.bus.read_half(dma.src[channel]))
```

DMA reads go directly through `bus.read_word` / `bus.read_half`. There is no latch. Whatever the bus returns (including 0 for unmapped regions) is written to the destination.

### Test failures caused

**Memory tests -- ROM load DMA0 (12 failures):**
DMA channel 0 has a 27-bit source address mask (`0x07FFFFFF` in `DMA_SRC_MASK`), which means it cannot access ROM (0x08000000+). When the test writes a ROM address to DMA0's source register, the upper bits are masked off, and the DMA reads from an unintended low address (BIOS or WRAM region) instead of ROM. Without a latch, the read returns whatever is at the masked address (typically 0) instead of the previous DMA latch value (`0xFEEDFACE`).

**Memory tests -- BIOS load via DMA (24 failures), BIOS out-of-bounds load via DMA (24 failures), Out-of-bounds load via DMA (24 failures):**
These tests verify that when DMA reads from a protected/unmapped source, the DMA latch value from a prior transfer (0xFEEDFACE) is preserved. Without latch implementation, the emulator writes 0 to the destination.

**DMA tests -- =ROM source tests (channel 0, ~24 failures):**
Same root cause as the Memory tests. DMA0 cannot access ROM; the latch should supply the value.

**DMA tests -- =BIOS source tests (all channels, ~48 failures):**
BIOS protection should prevent DMA from reading BIOS data. Without both BIOS protection and the DMA latch, some channels read raw BIOS bytes and others read 0.

**DMA tests -- -SRAM source tests (~16 failures):**
32-bit DMA reads from SRAM should use the latch since SRAM is 8-bit only.

### Changes needed

Add two latch fields to the `DMA` type in `src/dingbat/gba/gba.nim` (around line 112):

```nim
DMA* = ref object
  ...
  latch_half*: uint16   # 16-bit DMA read latch
  latch_word*: uint32   # 32-bit DMA read latch
```

In `dma.nim` `trigger()`, update the latch on each successful read and use the latch for writes:

```nim
for _ in 0 ..< len:
  if word_size == 4:
    let val = dma.gba.bus.read_word(dma.src[channel])
    # Update latch only if source is accessible (not open bus / not protected)
    # For simplicity, always update -- the bus already returns 0 for bad reads,
    # so we need the bus to signal "invalid" somehow, OR we check the source
    # region before reading.
    dma.latch_word = val
    dma.gba.bus.write_word(dma.dst[channel], dma.latch_word)
  else:
    let val = dma.gba.bus.read_half(dma.src[channel])
    dma.latch_half = val
    dma.gba.bus.write_half(dma.dst[channel], dma.latch_half)
```

The critical nuance: the latch should NOT be updated when the read is from an invalid/protected source. This means we need the bus read functions to distinguish "returned 0 because the memory is zero" from "returned 0 because the address is unmapped." Two approaches:

**Approach A (region check before read):** Before reading, check if the source address is accessible. If not, skip the read and use the existing latch value.

```nim
proc is_dma_readable(address: uint32): bool =
  let region = bits_range(address, 24, 27)
  case region
  of 0x0: false  # BIOS -- protected from DMA
  of 0x1: false  # unmapped
  of 0x2, 0x3, 0x4, 0x5, 0x6, 0x7: true
  of 0x8, 0x9, 0xA, 0xB, 0xC, 0xD: true  # ROM
  of 0xE, 0xF: true  # SRAM (8-bit only, but bus still returns a value)
  else: false
```

Then in the transfer loop:

```nim
if is_dma_readable(dma.src[channel]):
  if word_size == 4:
    dma.latch_word = dma.gba.bus.read_word(dma.src[channel])
  else:
    dma.latch_half = dma.gba.bus.read_half(dma.src[channel])
# Always write the latch to the destination
if word_size == 4:
  dma.gba.bus.write_word(dma.dst[channel], dma.latch_word)
else:
  dma.gba.bus.write_half(dma.dst[channel], dma.latch_half)
```

**Approach B (always read, let bus return latch):** Have the bus return the DMA latch for invalid addresses. This is more complex and couples bus and DMA.

**Recommendation:** Approach A is simpler and sufficient for passing the tests.

---

## 2. BIOS Read Protection

### What gbatek documents

The GBA has BIOS read protection:

- **When PC is within the BIOS region (0x00000000-0x00003FFF):** BIOS memory can be read normally.
- **When PC is outside the BIOS region:** Reading from the BIOS region returns the **last value that was successfully fetched from BIOS** (the "BIOS latch" or "last BIOS opcode").
- After a SWI or IRQ that enters the BIOS, the latch is updated with the last instruction fetched before returning. Typical latch values after returning from SWI include `0xE3A02004` (`mov r2, #4`) or `0xE25EF004` (`subs pc, lr, #4`), depending on which SWI was called and where it returned.
- At power-on (before BIOS has been executed), the latch is 0.
- **DMA is NOT exempt from BIOS protection.** DMA reads from BIOS return the last BIOS latch value, not the raw BIOS contents.

### What the emulator currently does

**File:** `src/dingbat/gba/bus.nim`, lines 59-61 (byte read), 84-85 (half read), 110-111 (word read)

```nim
proc read_byte_internal*(bus: Bus; address: uint32): uint8 {.inline.} =
  case bits_range(address, 24, 27)
  of 0x0: bus.bios[address and 0x3FFF'u32]   # <-- No protection!
```

All three read functions (`read_byte_internal`, `read_half_internal`, `read_word_internal`) for region 0x0 directly return BIOS data with no check on the CPU's PC. There is no BIOS latch stored anywhere.

### Test failures caused

**Memory tests -- BIOS load (CPU, 10 failures):**
Tests like `BIOS load 32 | 0x00000000 | 0xE3A02004` expect the BIOS latch value after a SWI. With the HLE BIOS stub, offset 0x00 is all zeros, so the raw read returns 0. With a real BIOS, the raw bytes at offset 0 would be the reset vector, not the expected latch value.

**Memory tests -- BIOS out-of-bounds load (CPU, 10 failures):**
Reading from BIOS addresses beyond 0x3FFF (or at addresses where BIOS data doesn't match the latch). Same root cause.

**DMA tests -- BIOS source tests (all channels, ~48 failures):**
DMA reads from BIOS should be blocked by protection, returning the DMA latch. Instead, raw BIOS data is returned. For the HLE stub, most addresses are 0; for offsets 0x18-0x2C, the stub IRQ handler instructions are returned (visible in the `R+0x10` tests where actual values like `E92D500F` appear).

### Changes needed

Add a BIOS latch field to `Bus` in `src/dingbat/gba/gba.nim` (around line 138):

```nim
Bus* = ref object
  ...
  bios_latch*: uint32  # last value fetched while PC was in BIOS
```

In the bus read functions (region 0x0), check whether the caller is the CPU with PC in BIOS:

```nim
proc read_byte_internal*(bus: Bus; address: uint32): uint8 {.inline.} =
  case bits_range(address, 24, 27)
  of 0x0:
    if bits_range(bus.gba.cpu.r[15], 24, 27) == 0x0:
      # PC is in BIOS -- allow read and update latch
      let val = bus.bios[address and 0x3FFF'u32]
      # Update latch (the latch stores the last full word fetched from BIOS)
      # For simplicity during instruction fetch, update on word reads
      val
    else:
      # PC is outside BIOS -- return latch
      uint8(bus.bios_latch shr ((address and 3) * 8))
```

Similarly for `read_half_internal` and `read_word_internal`. The latch should be updated during instruction fetch when PC is in BIOS. The most accurate approach:

- During opcode fetch (in `fill_pipeline` / `read_instr`), when reading from BIOS region, update the latch with the full 32-bit word (even for Thumb fetches, the latch stores the full 32-bit value at the aligned address).
- For data reads from BIOS when PC is in BIOS, update the latch with the read value.
- For reads when PC is NOT in BIOS, return the latch (shifted appropriately for byte/halfword reads).

**Important for DMA:** When DMA reads from BIOS, the CPU's PC is certainly not in BIOS (CPU is paused). So the protection check using `cpu.r[15]` will correctly block DMA from reading raw BIOS data. The bus should return the BIOS latch value, which the DMA latch mechanism (from section 1) will then use or not depending on whether we consider BIOS a "failed" read.

For the DMA latch interaction: BIOS-protected reads should be treated as "open bus" from DMA's perspective. The DMA latch should NOT be updated when reading from BIOS (since the data returned is the BIOS latch, not real data from the source). This is handled by the `is_dma_readable` check returning `false` for region 0x0.

---

## 3. CPU Open Bus / Last Prefetch Latch

### What gbatek documents

When the CPU reads from an unmapped address (region 0x1, addresses >= 0x10000000, etc.), it returns the value from the CPU's prefetch pipeline:

- **ARM mode:** Returns the current prefetched 32-bit word (the value of the opcode at `PC`).
- **Thumb mode:** Returns the current prefetched 16-bit halfword, replicated to fill 32 bits: `(opcode << 16) | opcode`.
- The exact value depends on the pipeline stage and access type, but the most common approximation is to use the opcode at the current PC.

### What the emulator currently does

**File:** `src/dingbat/gba/bus.nim`, lines 62, 86, and elsewhere:

```nim
of 0x1: 0'u8   # open bus todo
of 0x1: 0'u16
```

Region 0x1 explicitly returns 0 with a `# open bus todo` comment. Addresses above 0xF are not handled (would raise an exception). The `read_open_bus_value` proc (lines 265-279) exists but is only used for MMIO open bus reads, not for general unmapped memory regions.

### Test failures caused

**Memory tests -- Out-of-bounds load (CPU, 10 failures):**
Tests like `Out-of-bounds load 32 | 0x00000000 | 0xE3A02007` expect the CPU prefetch value. The emulator returns 0.

**Memory tests -- BIOS out-of-bounds load (CPU, 10 failures):**
Reading from BIOS addresses >= 0x4000 (beyond BIOS). Should return the BIOS latch, but the emulator reads from the BIOS buffer (which wraps, potentially returning valid BIOS data or 0).

Note: The out-of-bounds tests expect values like `0xE3A02007` (`mov r2, #7`), which would be the opcode at the CPU's current PC. These are NOT the BIOS latch -- they are the open bus / prefetch values.

### Changes needed

The `read_open_bus_value` proc already exists and computes the right value from the CPU's pipeline. Use it for all unmapped regions:

**File:** `src/dingbat/gba/bus.nim`

In `read_byte_internal`, `read_half_internal`, `read_word_internal`:

```nim
of 0x1:
  bus.read_open_bus_value(address)  # instead of 0

# And add a catch-all for high addresses:
else:
  bus.read_open_bus_value(address)  # instead of raising
```

Similarly, create `read_open_bus_half` and `read_open_bus_word` helpers (or modify `read_open_bus_value` to support multi-byte reads) so that halfword and word reads return the correct pipeline value directly rather than assembling from byte reads.

---

## 4. DMA Tests Section -- Detailed Failure Analysis

### `=ROM` source tests (channel 0)

Test format: `{channel} {timing} {width} {src_mode}{source}/{dst_mode}{dest} {count}`

Example: `0 Imm H =ROM/=IWRAM 3` -- DMA channel 0, immediate trigger, halfword, fixed ROM source, fixed IWRAM dest, 3 transfers.

**Root cause:** DMA0 source mask is 27-bit (`0x07FFFFFF`). ROM addresses (0x08xxxxxx) are masked to 0x00xxxxxx. DMA reads from BIOS/WRAM region instead of ROM, getting 0 (or BIOS data) instead of ROM data. Without DMA latch, the destination gets the wrong value.

**Fix:** Implement DMA latch (Section 1). When DMA0 tries to read from a masked address that doesn't match the intended source, the latch provides the expected value.

### `=BIOS` source tests (all channels)

Example: `0 Imm W =BIOS/=IWRAM 3 | 00000000 | BABEBABE`

**Root cause:** No BIOS protection + no DMA latch. The DMA reads raw BIOS data (0 for most HLE stub addresses, or actual stub instructions for 0x18+). Expected behavior: BIOS protection blocks the read, DMA latch retains previous value.

**Fix:** Implement BIOS protection (Section 2) + DMA latch (Section 1).

### `+BIOS` source tests (incrementing, all channels)

Example: `0 Imm W +BIOS/=IWRAM 3 | E92D500F | CAFECAFE`

**Root cause:** Same as above. DMA reads actual BIOS IRQ handler stub (`E92D500F` = `stmfd sp!, {r0-r3, r12, lr}` at offset 0x18). Should be blocked by BIOS protection.

### `R+0x10` tests (BIOS region, incrementing)

Example: `0 Imm W R+0x10/+IWRAM 3 | E3A00301 | 00000000`

**Root cause:** DMA reads from BIOS starting at offset ~0x1C, getting the actual stub instructions. BIOS protection should block these reads. For channel 0, expected is 0 (no prior latch); for channels 1-3, expected is `DEADDEAD` (the pre-fill value at the destination, unchanged because DMA should write the latch which is 0 or DEADDEAD from prior setup).

### `-SRAM` source tests

Example: `0 Imm W -SRAM/=IWRAM 3 | A5B6C7D8 | 00000000`

**Root cause:** SRAM is 8-bit only. 32-bit DMA reads from SRAM should use the DMA latch for the upper bytes or get open bus. The emulator's `storage.read_word` likely returns an incorrect 32-bit value assembled from 8-bit SRAM reads.

### `V+BIOS/+VRAM` tests

Example: `0 Imm H V+BIOS/+VRAM 3 | 00000000 | CAFECAFE`

**Root cause:** Same BIOS protection issue. VBlank-triggered DMA from BIOS source should be blocked.

---

## 5. Summary of Required Changes

### Priority order (most impact first):

1. **DMA internal latch** (`src/dingbat/gba/dma.nim` + `src/dingbat/gba/gba.nim`)
   - Add `latch_half: uint16` and `latch_word: uint32` fields to `DMA` type
   - In `trigger()`, check source accessibility before reading
   - Update latch only on successful reads; always write latch to destination
   - Expected to fix: ~96 DMA-related failures in Memory tests + ~80 in DMA tests

2. **BIOS read protection** (`src/dingbat/gba/bus.nim` + `src/dingbat/gba/gba.nim`)
   - Add `bios_latch: uint32` field to `Bus` type
   - Guard BIOS reads with PC-in-BIOS check
   - Update latch during instruction fetches from BIOS region
   - Expected to fix: ~10 BIOS CPU load failures + contributes to DMA BIOS fixes

3. **CPU open bus for unmapped regions** (`src/dingbat/gba/bus.nim`)
   - Use existing `read_open_bus_value` for region 0x1 and other unmapped regions
   - Expected to fix: ~10 out-of-bounds load failures

### Files to modify:

| File | Change |
|------|--------|
| `src/dingbat/gba/gba.nim` (line ~105-112) | Add `latch_half`, `latch_word` to `DMA` type; add `bios_latch` to `Bus` type |
| `src/dingbat/gba/dma.nim` (lines 107-113) | Implement latch-aware DMA transfer loop with source accessibility check |
| `src/dingbat/gba/bus.nim` (lines 59-61, 84-86, 110-111) | Add BIOS protection check to region 0x0 reads |
| `src/dingbat/gba/bus.nim` (line 62, 86) | Replace `0` returns for region 0x1 with `read_open_bus_value` |
| `src/dingbat/gba/cpu.nim` (lines 74-104) | Update BIOS latch during instruction fetch from BIOS |

---

## 6. DMA Open Bus / Latch Behavior -- Detailed Specification

### Latch update rules:

| Source region | DMA latch updated? | Value written to dest |
|--------------|--------------------|-----------------------|
| EWRAM (0x02) | Yes | Read value |
| IWRAM (0x03) | Yes | Read value |
| I/O (0x04) | Yes | Read value |
| Palette (0x05) | Yes | Read value |
| VRAM (0x06) | Yes | Read value |
| OAM (0x07) | Yes | Read value |
| ROM (0x08-0x0D) | Yes (if addr reachable by channel) | Read value |
| SRAM (0x0E-0x0F) | Special: 8-bit only, upper bits from latch | Mixed |
| BIOS (0x00) | No (protected) | Previous latch value |
| Unmapped (0x01, 0x10+) | No | Previous latch value |
| ROM via DMA0 (masked away) | No (addr becomes non-ROM) | Previous latch value |

### SRAM special case:

SRAM only supports 8-bit reads. When DMA does a 16-bit or 32-bit read from SRAM:
- The 8-bit value is read from SRAM
- It is replicated across all bytes: `val | (val << 8)` for 16-bit, `val | (val << 8) | (val << 16) | (val << 24)` for 32-bit
- The DMA latch IS updated with this replicated value
- Note: the current `storage.read_word` / `storage.read_half` implementations may need to be verified for this replication behavior
