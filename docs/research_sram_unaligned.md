# SRAM Unaligned Access Bug Analysis

## Summary

Approximately 30 mGBA test suite failures in the "Memory tests" section stem from
incorrect handling of 16-bit and 32-bit accesses to the SRAM region (0x0E000000).
GBA SRAM sits on an 8-bit data bus, which means the hardware can only transfer one
byte per access. The emulator currently treats SRAM halfword/word accesses
incorrectly in two ways: it force-aligns the address before reading the byte, and
it writes multiple bytes instead of one.

## What the tests expect

Per gbatek, the GBA memory map assigns SRAM an 8-bit bus width. The key behaviors
for an 8-bit bus are:

### Reads (LDRH / LDR to SRAM)

When the CPU issues a 16-bit or 32-bit read to an 8-bit bus region:

1. The bus performs a single 8-bit read at the **exact byte address** (no
   alignment masking -- the full address including bits 0-1 goes to the SRAM
   chip).
2. The resulting byte is **replicated across all lanes** of the data bus:
   - 16-bit read: `byte | (byte << 8)` (same byte in both halfword lanes)
   - 32-bit read: `byte | (byte << 8) | (byte << 16) | (byte << 24)`
3. The ARM CPU then applies its normal rotation for misaligned LDR (rotate right
   by `(address & 3) * 8`), but since all lanes hold the same byte, the rotation
   has no visible effect -- the result is always `0x01010101 * byte`.

### Writes (STRH / STR to SRAM)

When the CPU issues a 16-bit or 32-bit write to an 8-bit bus region:

1. Only **one byte** is written, at the **exact byte address** (no alignment).
2. The byte that reaches the 8-bit data bus is the **least significant byte** of
   the value being stored (bits 0-7 of the register). On an 8-bit bus, D0-D7
   carry this byte regardless of the address alignment, because the CPU mirrors
   the low byte across all data lanes during a store.
3. The remaining bytes of the value are lost -- they never reach the bus.

### Test data pattern

The mGBA memory tests write the ASCII string "Game" (`0x47 0x61 0x6D 0x65`) to
SRAM at a base address, then test unaligned access patterns:

- **Load tests**: A 32-bit read at base+1 should fetch byte `0x61` ('a') and
  replicate it: `0x61616161`. At base+2: `0x6D6D6D6D`. At base+3: `0x65656565`.
- **Store tests**: A 32-bit or 16-bit write with value containing LSB `0x66`
  should store exactly `0x66` at the target byte. Readback (replicated) yields
  `0x66666666`.

## What the emulator currently does

### Read path -- wrong address alignment

**File**: `src/dingbat/gba/storage.nim`, lines 49-53

```nim
proc read_half*(st: Storage; address: uint32): uint16 =
  0x0101'u16 * uint16(st[address and not 1'u32])

proc read_word*(st: Storage; address: uint32): uint32 =
  0x01010101'u32 * uint32(st[address and not 3'u32])
```

The replication multiplier (`0x0101` / `0x01010101`) is correct, but the address
is **force-aligned** before the byte read. This discards the low 1 or 2 bits of
the address, causing the wrong byte to be fetched.

Additionally, the callers in `bus.nim` also force-align before dispatching:

**File**: `src/dingbat/gba/bus.nim`, lines 82-83 (`read_half_internal`):
```nim
proc read_half_internal*(bus: Bus; address: uint32): uint16 {.inline.} =
  let address = address and not 1'u32
```

**File**: `src/dingbat/gba/bus.nim`, lines 108-109 (`read_word_internal`):
```nim
proc read_word_internal*(bus: Bus; address: uint32): uint32 {.inline.} =
  let address = address and not 3'u32
```

The force-alignment is applied unconditionally before the region dispatch. For
SRAM, this means address bits 0-1 are zeroed before reaching `storage.read_half`
or `storage.read_word`. Double-alignment occurs but the result is the same: the
byte at the aligned address is read instead of the byte at the original address.

**Concrete example**: 32-bit read at SRAM base+1 (where bytes are `G a m e`):
- Original address has bit 0 set, bits 1-0 = `01`
- `read_word_internal` masks to `address and not 3` -> base+0
- `storage.read_word` reads `st[base+0 and not 3]` = `st[base+0]` = `0x47` ('G')
- Returns `0x47474747` instead of expected `0x61616161`

### Write path -- writes too many bytes

**File**: `src/dingbat/gba/bus.nim`, lines 183-186 (`write_half_internal`):
```nim
of 0xE, 0xF:
    bus.write_byte_internal(address, uint8(value))
    bus.write_byte_internal(address + 1, uint8(value shr 8))
```

This writes **two** bytes to consecutive SRAM locations. On real hardware, only
one byte should be written.

**File**: `src/dingbat/gba/bus.nim`, lines 212-216 (`write_word_internal`):
```nim
of 0xE, 0xF:
    bus.write_byte_internal(address,     uint8(value))
    bus.write_byte_internal(address + 1, uint8(value shr 8))
    bus.write_byte_internal(address + 2, uint8(value shr 16))
    bus.write_byte_internal(address + 3, uint8(value shr 24))
```

This writes **four** bytes. On real hardware, only one byte should be written.

Furthermore, because the address was force-aligned at the top of these functions
(line 163 for halfword, line 190 for word), the single byte is written to the
wrong address.

**Concrete example**: 32-bit write of `0xA5B6C7D8` at SRAM base+1:
- `write_word_internal` aligns address to base+0
- Writes `0xD8` to base+0, `0xC7` to base+1, `0xB6` to base+2, `0xA5` to base+3
- On real hardware: should write only `0xD8` to base+1 (the original unaligned
  address), leaving other bytes untouched

This explains why the store tests see `0xD8` instead of `0x66` -- the write
value and alignment are both wrong.

## Required changes

### 1. `storage.nim` -- fix `read_half` and `read_word` address masking

Remove the force-alignment from the byte address in `read_half` and `read_word`.
The byte read should use the raw address:

```nim
proc read_half*(st: Storage; address: uint32): uint16 =
  0x0101'u16 * uint16(st[address])

proc read_word*(st: Storage; address: uint32): uint32 =
  0x01010101'u32 * uint32(st[address])
```

The `st[address]` call (`SRAM.[]`) already masks to `address and 0x7FFF`, so no
additional masking is needed.

### 2. `bus.nim` -- pass the original unaligned address for SRAM reads

In `read_half_internal` (line 105), the address has already been force-aligned at
line 83. The SRAM case needs the original address. Two approaches:

**Option A** (minimal change): Save the original address before alignment and pass
it to the storage read for the 0xE/0xF case:

```nim
proc read_half_internal*(bus: Bus; address: uint32): uint16 {.inline.} =
  let orig = address
  let address = address and not 1'u32
  case bits_range(address, 24, 27)
  ...
  of 0xE, 0xF: bus.gba.storage.read_half(orig)
```

Similarly for `read_word_internal` (line 133):

```nim
proc read_word_internal*(bus: Bus; address: uint32): uint32 {.inline.} =
  let orig = address
  let address = address and not 3'u32
  case bits_range(address, 24, 27)
  ...
  of 0xE, 0xF: bus.gba.storage.read_word(orig)
```

**Option B** (alternative): Since `bits_range(address, 24, 27)` only looks at bits
24-27, masking bits 0-1 does not affect the region dispatch. The SRAM handlers
could simply use the parameter `address` as passed (before the `let` shadow) --
but in Nim the `let` rebinding shadows the parameter, so Option A with `orig` is
cleaner.

### 3. `bus.nim` -- fix SRAM write_half and write_word to write only one byte

For `write_half_internal` (lines 183-185), change the 0xE/0xF case to write a
single byte at the original (unaligned) address. The byte value is the LSB:

```nim
of 0xE, 0xF:
    bus.gba.storage[orig] = uint8(value)
```

For `write_word_internal` (lines 212-216), same fix:

```nim
of 0xE, 0xF:
    bus.gba.storage[orig] = uint8(value)
```

Both need the `orig` address saved before the force-alignment `let` binding, just
as described for reads above.

### 4. Flash memory (optional, same bus width)

Flash memory (regions 0xE/0xF when storage type is FLASH) also uses an 8-bit bus.
The same fix should apply. Check `src/dingbat/gba/storage/flash.nim` to ensure
its read/write handlers follow the same pattern. The `storage.read_half` and
`storage.read_word` base methods already serve both SRAM and Flash, so fixing
those fixes both.

## Summary of byte mirroring/replication behavior

| Access type | Bus width | Bytes transferred | Data on bus                    |
|-------------|-----------|-------------------|--------------------------------|
| LDRB        | 8-bit     | 1 byte read       | `byte` at exact address        |
| LDRH        | 8-bit     | 1 byte read       | `byte \| (byte << 8)`          |
| LDR         | 8-bit     | 1 byte read       | `byte * 0x01010101`            |
| STRB        | 8-bit     | 1 byte written    | LSB of register value          |
| STRH        | 8-bit     | 1 byte written    | LSB of register value          |
| STR         | 8-bit     | 1 byte written    | LSB of register value          |

The byte address is never force-aligned for 8-bit bus regions. The address lines
A0 and A1 pass through to the SRAM chip directly, selecting the exact byte.
