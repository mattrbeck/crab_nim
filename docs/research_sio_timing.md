# SIO Normal Mode Timing -- Research Notes

## Problem

All 4 mGBA SIO timing tests fail, each off by exactly 0x38 (56 decimal) cycles.
The emulator consistently completes transfers 56 cycles too fast.

| Test | Actual | Expected | Diff |
|------|--------|----------|------|
| Normal8/256k  | 0x0241 (577)  | 0x0279 (633)  | +56 |
| Normal8/2M    | 0x0081 (129)  | 0x00B9 (185)  | +56 |
| Normal32/256k | 0x0841 (2113) | 0x0879 (2169) | +56 |
| Normal32/2M   | 0x0141 (321)  | 0x0179 (377)  | +56 |

## GBA SIO Normal Mode Timing (per gbatek)

The GBA's SIO in Normal mode shifts data serially, one bit per clock pulse.

**Clock rates** (SIOCNT bit 1):
- Slow (bit 1 = 0): 256 KHz = 64 CPU cycles per bit
- Fast (bit 1 = 1): 2 MHz = 8 CPU cycles per bit

**Transfer widths** (SIOCNT bit 12):
- 8-bit mode: 8 bits transferred
- 32-bit mode: 32 bits transferred

**Transfer initiation**: Setting SIOCNT bit 7 (Start/Busy) begins the transfer
when using internal clock (SIOCNT bit 0 = 1).

**Key timing detail from gbatek**: The total transfer duration is not simply
`bits * cycles_per_bit`. According to gbatek's SIO Normal Mode documentation,
the transfer takes additional cycles beyond the raw bit-clocking time. The
hardware has a startup latency after the Start bit is set before the first
serial clock edge, plus a finalization period after the last bit is clocked
before the Start/Busy flag is cleared and the IRQ fires.

## What the Emulator Currently Does

**File**: `src/dingbat/gba/serial.nim`, lines 108-119

```nim
proc start_normal_transfer(serial: Serial) =
  let internal_clock = bit(serial.siocnt, 0)
  if not internal_clock:
    return

  let is_32bit = bit(serial.siocnt, 12)
  let fast = bit(serial.siocnt, 1)
  let bits = if is_32bit: 32 else: 8
  let cycles_per_bit = if fast: 8 else: 64
  let total_cycles = bits * cycles_per_bit

  serial.gba.scheduler.schedule(total_cycles, etSerial)
```

The emulator schedules the transfer completion event at exactly
`bits * cycles_per_bit` cycles after the Start bit is written. There is no
startup delay or completion overhead.

## The Math

### Isolating the test framework overhead

All 4 tests show a constant offset from the pure transfer time. This overhead
comes from the test ROM's own instructions (writing SIOCNT, polling or reading
the timer, etc.). We can extract it:

| Test | Emulator result | Pure transfer (bits * cpb) | Overhead |
|------|----------------|---------------------------|----------|
| Normal8/256k  | 577  | 8 * 64 = 512  | 577 - 512 = 65 |
| Normal8/2M    | 129  | 8 * 8 = 64    | 129 - 64 = 65  |
| Normal32/256k | 2113 | 32 * 64 = 2048| 2113 - 2048 = 65|
| Normal32/2M   | 321  | 32 * 8 = 256  | 321 - 256 = 65 |

The test framework adds a consistent 65 cycles of overhead (from the
instructions that set up the timer, write SIOCNT, and read back the result).
This is the same across all 4 tests, confirming the framework overhead is fixed.

### What the tests expect

| Test | Expected | Overhead | Expected transfer time |
|------|----------|----------|----------------------|
| Normal8/256k  | 633  | 65 | 633 - 65 = 568  |
| Normal8/2M    | 185  | 65 | 185 - 65 = 120  |
| Normal32/256k | 2169 | 65 | 2169 - 65 = 2104 |
| Normal32/2M   | 377  | 65 | 377 - 65 = 312  |

### Comparing to raw bit-clocking time

| Test | Expected xfer | bits * cpb | Difference |
|------|--------------|------------|------------|
| Normal8/256k  | 568  | 512  | **56** |
| Normal8/2M    | 120  | 64   | **56** |
| Normal32/256k | 2104 | 2048 | **56** |
| Normal32/2M   | 312  | 256  | **56** |

The hardware takes exactly **56 cycles longer** than `bits * cycles_per_bit`
to complete a Normal mode transfer. This 56-cycle overhead is:

- **Independent of bit count** (same for 8-bit and 32-bit) -- so it is not
  "per bit" overhead
- **Independent of clock rate** (same for 256 KHz and 2 MHz) -- so it is not
  measured in serial clock ticks, but in CPU cycles

This means the 56 cycles is a **fixed startup/completion latency** measured in
CPU clock cycles, applied once per transfer regardless of mode or speed.

### Nature of the 56-cycle delay

The 56-cycle constant most likely represents:

1. **Startup latency** (most probable): After the CPU writes the Start bit to
   SIOCNT, the serial hardware does not begin clocking immediately. There is
   an internal synchronization delay before the first serial clock edge. The
   GBA's serial controller likely synchronizes to an internal divider or
   performs some initialization before driving the clock line. This is
   analogous to how many serial peripherals have a "start condition" delay.

2. **Completion overhead**: After the last bit is clocked, the hardware may
   take additional cycles to latch the received data into the data register,
   clear the Start/Busy flag, and assert the IRQ line.

3. **Combination**: Some cycles at the start + some at the end.

Since the 56 cycles break down as 56 = 7 * 8 (seven 2 MHz serial clock
periods) or 56 = 0.875 * 64 (less than one 256 KHz period), and the value is
the same regardless of clock speed, this is definitively a **CPU-cycle-counted
fixed delay**, not a serial-clock-counted delay.

## Required Fix

**File**: `src/dingbat/gba/serial.nim`, line 117

Change the total cycle calculation from:

```nim
let total_cycles = bits * cycles_per_bit
```

to:

```nim
let total_cycles = bits * cycles_per_bit + 56
```

This adds the 56-cycle fixed hardware latency to every Normal mode SIO
transfer, matching real hardware behavior as validated by the mGBA test suite.

The constant `56` should ideally be given a descriptive name:

```nim
const SIO_TRANSFER_OVERHEAD = 56  # Fixed startup/completion latency in CPU cycles
# ...
let total_cycles = bits * cycles_per_bit + SIO_TRANSFER_OVERHEAD
```

No other changes are needed. The transfer completion handler
(`serial_transfer_complete` at line 121) correctly clears the Start/Busy bit,
fills received data with 0xFF (no cable connected), and fires the IRQ. The
only issue is the scheduling delay being 56 cycles too short.
