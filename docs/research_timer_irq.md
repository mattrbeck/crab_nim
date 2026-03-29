# Timer IRQ Test Failures: Root Cause Analysis

## Test Results Summary

All 90 Timer IRQ tests in the mGBA test suite fail (0/90 passed). Every test
reports empty actual and expected values, meaning the test output contains
only `FAIL: <test_name>` lines without value comparisons. The test names
follow the pattern `FFFF 0 nops`, `FFFF 1 nop`, `FFFE 3 nops`, etc.,
where the hex value is the timer reload value and the number indicates how
many NOP instructions are executed between enabling the timer and checking
the result.

The fact that the suite completes (does not hang) but reports all failures
with no values indicates the timer overflow -> IRQ handler call path is
non-functional, though the timer overflow mechanism itself partially works
(333/936 timer count-up tests pass).

## How Timer IRQs Work on Real Hardware (per gbatek/tonc)

### Timer Overflow -> IRQ Path

1. **Timer overflow**: When a timer's counter wraps from 0xFFFF to 0x0000,
   the counter reloads from TM_CNT_L (the reload register) and an overflow
   event occurs.

2. **IF flag set**: If the timer's IRQ enable bit (TMCNT_H bit 6) is set,
   the corresponding bit in the IF register (0x04000202) is set:
   - Timer 0 -> IF bit 3
   - Timer 1 -> IF bit 4
   - Timer 2 -> IF bit 5
   - Timer 3 -> IF bit 6

3. **Interrupt check**: The CPU checks `IE AND IF`. If non-zero and IME=1
   and CPSR.I=0 (IRQ not disabled), the CPU takes the IRQ exception.

4. **IRQ exception**: The CPU switches to IRQ mode, saves CPSR to SPSR_irq,
   sets LR_irq = PC+4 (for return), disables IRQs (CPSR.I=1), and jumps
   to the IRQ vector at 0x00000018.

5. **BIOS IRQ handler** (at 0x18, real BIOS branches to 0x128):
   - Saves {r0-r3, r12, lr} on the IRQ stack
   - Reads IE (0x04000200) and IF (0x04000202)
   - ANDs them to determine which interrupts are being serviced
   - **ORs the serviced bits into [0x03007FF8]** (BIOS IntrCheck flags)
   - **Writes the serviced bits back to IF** to acknowledge (write-1-to-clear)
   - Calls the user IRQ handler at [0x03FFFFFC]
   - Restores {r0-r3, r12, lr}
   - Returns from IRQ via `SUBS PC, LR, #4`

6. **User handler**: The application's IRQ handler runs. It can read IF
   to determine which interrupt fired, perform actions, and return via
   `BX LR`.

### IntrWait (SWI 0x04) and Halt (SWI 0x02)

The real BIOS IntrWait:
1. If r0 != 0, clears the requested IF bits
2. ORs the requested interrupt mask into IE
3. **Sets IME = 1**
4. Enters a loop:
   a. Halts the CPU (writes to HALTCNT)
   b. On wake, checks [0x03007FF8] against the requested flags
   c. If the requested interrupt is found, clears those bits and returns
   d. Otherwise, loops back to halt

The real BIOS Halt (SWI 0x02):
1. Simply writes to HALTCNT (0x04000301 bit 7 = 0)
2. CPU halts until any enabled interrupt fires

## What the Emulator Currently Does

### Timer Overflow -> IRQ Path (appears structurally correct)

**File: `src/dingbat/gba/timer.nim` lines 10-28**

When a scheduler timer event fires, `timer_overflow_event` is called:
```nim
proc timer_overflow_event*(tim: Timer; num: int) =
  tim.tm[num] = tim.tmd[num]                    # reload counter
  tim.cycle_enabled[num] = tim.gba.scheduler.cycles
  # ... cascade handling ...
  if tim.tmcnt[num].irq_enable:
    case num
    of 0: tim.gba.interrupts.reg_if.timer0 = true   # set IF bit
    of 1: tim.gba.interrupts.reg_if.timer1 = true
    of 2: tim.gba.interrupts.reg_if.timer2 = true
    of 3: tim.gba.interrupts.reg_if.timer3 = true
    else: discard
    tim.gba.interrupts.schedule_interrupt_check()    # schedule IRQ check
  # reschedule next overflow ...
```

This correctly sets the IF flag and schedules an interrupt check.

**File: `src/dingbat/gba/interrupts.nim` lines 9-16**

```nim
proc schedule_interrupt_check*(intr: Interrupts) =
  intr.gba.scheduler.schedule(0, etInterrupts)

proc check_interrupts*(intr: Interrupts) =
  if (uint16(intr.reg_ie) and uint16(intr.reg_if)) != 0:
    intr.gba.cpu.halted = false
    if intr.ime:
      intr.gba.cpu.irq()
```

The interrupt check correctly:
- Unhalts the CPU if any enabled interrupt is pending
- Calls `cpu.irq()` if IME is enabled

**File: `src/dingbat/gba/cpu.nim` lines 57-64**

```nim
proc irq*(cpu: CPU) =
  if not cpu.cpsr.irq_disable:
    let lr = cpu.r[15] - (if cpu.cpsr.thumb: 0'u32 else: 4'u32)
    cpu.switch_mode(modeIRQ)
    cpu.cpsr.thumb = false
    cpu.cpsr.irq_disable = true
    discard cpu.set_reg(14, lr)
    discard cpu.set_reg(15, 0x18'u32)
```

This correctly switches to IRQ mode and jumps to the BIOS IRQ vector.

### BIOS IRQ Stub (correct but incomplete)

**File: `src/dingbat/gba/bus.nim` lines 25-37**

When no real BIOS file is provided (HLE mode), a minimal IRQ stub is
installed at address 0x18:

```
0x18: stmfd sp!, {r0-r3, r12, lr}   ; save registers
0x1C: mov   r0, #0x04000000         ; r0 = IO base
0x20: add   lr, pc, #0              ; lr = 0x28 (return addr)
0x24: ldr   pc, [r0, #-4]           ; jump to [0x03FFFFFC]
0x28: ldmfd sp!, {r0-r3, r12, lr}   ; restore registers
0x2C: subs  pc, lr, #4              ; return from IRQ
```

This stub correctly calls the user IRQ handler at [0x03FFFFFC] and
returns from the exception. However, it is **missing critical behavior**
that the real BIOS performs (see issues below).

### HLE IntrWait (SWI 0x04) -- multiple bugs

**File: `src/dingbat/gba/arm/arm.nim` lines 76-84**

```nim
of 0x04:  # IntrWait(discard_flags, intr_flags)
    let discard_flags = cpu.r[0]
    let intr_mask = uint16(cpu.r[1])
    if discard_flags != 0:
      cpu.gba.interrupts.reg_if =
        cast[InterruptReg](uint16(cpu.gba.interrupts.reg_if) and not intr_mask)
    cpu.gba.interrupts.reg_ie =
      cast[InterruptReg](uint16(cpu.gba.interrupts.reg_ie) or intr_mask)
    cpu.halted = true
```

## Identified Issues

### Issue 1: HLE IntrWait does not set IME = 1 (CRITICAL)

**Impact: Timer IRQs are silently dropped if IME was not already enabled**

The real BIOS IntrWait sets IME = 1 before halting. The HLE version
does not. If the test ROM calls IntrWait without having explicitly set
IME = 1 first, the `check_interrupts` function will unhalt the CPU but
will NOT call `cpu.irq()` because `intr.ime` is false. The interrupt
is effectively lost.

**Fix**: Add `cpu.gba.interrupts.ime = true` in the HLE IntrWait handler
before setting `cpu.halted = true`.

**File: `src/dingbat/gba/arm/arm.nim` line 84**

### Issue 2: HLE IntrWait does not loop (CRITICAL)

**Impact: Non-matching interrupts cause IntrWait to return prematurely**

The real BIOS IntrWait loops: halt -> check if desired interrupt fired
-> if not, halt again. The HLE version halts once. When ANY interrupt
(e.g., VBlank) unhalts the CPU, execution continues past the SWI
instruction without checking whether the DESIRED interrupt actually
fired.

For timer IRQ tests, if a VBlank interrupt fires before the timer
overflows, the test would prematurely continue and find that the timer
IRQ never occurred.

**Fix**: The HLE IntrWait needs to implement the loop behavior. After
the CPU unhalts and the IRQ handler runs, the emulator should check if
the requested interrupt was serviced. If not, halt again. This could be
done by:
- Storing the IntrWait mask in a persistent field
- After returning from the IRQ handler, checking if the mask is
  satisfied before allowing execution to continue

Alternatively, a simpler approach: track a "waiting for interrupt"
state that re-halts the CPU after each IRQ until the desired interrupt
is found in the BIOS flags at 0x03007FF8.

**File: `src/dingbat/gba/arm/arm.nim` lines 76-84**

### Issue 3: BIOS IRQ stub does not update IntrCheck flags at 0x03007FF8 (CRITICAL)

**Impact: IntrWait can never detect that an interrupt was serviced**

On real hardware, the BIOS IRQ handler (at 0x128) reads IE & IF, ORs
the result into the word at 0x03007FF8, and then acknowledges IF. The
IntrWait loop checks 0x03007FF8 to determine if the desired interrupt
has been serviced.

The emulator's BIOS stub at 0x18 does none of this. It jumps directly
to the user handler without updating 0x03007FF8 or acknowledging IF.

Even though the HLE IntrWait bypasses the BIOS IntrWait code, the
0x03007FF8 flags are still important because:
- Some games read them directly
- Mixed HLE/real-BIOS scenarios depend on them
- Test ROMs may check them

**Fix**: Expand the BIOS IRQ stub to include the IE & IF acknowledgment
logic, OR implement this in the HLE interrupt handling path. The stub
could be extended to approximately:

```
stmfd sp!, {r0-r3, r12, lr}
mov   r0, #0x04000000
ldr   r1, [r0, #0x200]     ; read IE|IF (IE in low halfword, IF in high)
and   r2, r1, r1, lsr #16  ; r2 = IE & IF (acknowledged interrupts)
ldrh  r3, [r0, #-8]        ; load [0x03007FF8] (current BIOS IF flags)
orr   r3, r3, r2           ; OR in newly acknowledged interrupts
strh  r3, [r0, #-8]        ; store back to [0x03007FF8]
strh  r2, [r0, #0x202]     ; acknowledge IF (write-1-to-clear)
add   lr, pc, #0
ldr   pc, [r0, #-4]        ; call user handler at [0x03FFFFFC]
ldmfd sp!, {r0-r3, r12, lr}
subs  pc, lr, #4
```

**File: `src/dingbat/gba/bus.nim` lines 25-37**

### Issue 4: HLE VBlankIntrWait has the same problems (MODERATE)

**File: `src/dingbat/gba/arm/arm.nim` lines 85-88**

```nim
of 0x05:  # VBlankIntrWait
    cpu.gba.interrupts.reg_if.vblank = false
    cpu.gba.interrupts.reg_ie.vblank = true
    cpu.halted = true
```

Same issues as IntrWait: doesn't set IME, doesn't loop. The timer IRQ
tests may depend on VBlankIntrWait working correctly for the test
framework's main loop.

### Issue 5: Timer count-up accuracy (CONTRIBUTING)

333/936 timer count-up tests fail, indicating fundamental timer tick
counting accuracy issues. While these are separate from the IRQ
delivery problem, inaccurate timer values could cause some IRQ timing
tests to fail even if the IRQ path is fixed.

Potential timer accuracy issues:
- The `cycles_until_overflow` calculation uses integer division, which
  rounds down. This could cause off-by-one timing errors.
- When re-enabling an already-enabled timer (without changing the
  enable bit), the scheduler event is not rescheduled
  (`src/dingbat/gba/timer.nim` lines 69-73: the `elif not was_enabled
  or was_cascade` check skips rescheduling).

## Recommended Fix Priority

1. **Issue 3 (BIOS IRQ stub)**: Expand the BIOS stub to update
   0x03007FF8 and acknowledge IF. This is the most fundamental fix
   because it affects ALL interrupt-driven code paths, not just HLE
   SWI calls.

2. **Issue 1 (IME in IntrWait)**: Add `cpu.gba.interrupts.ime = true`
   to both IntrWait and VBlankIntrWait HLE handlers.

3. **Issue 2 (IntrWait loop)**: Implement proper wait-loop semantics
   so IntrWait only returns when the requested interrupt has fired.

4. **Issue 5 (Timer accuracy)**: Fix timer count-up accuracy to ensure
   correct overflow timing.

## Edge Cases to Watch

1. **Nested interrupts**: If the user IRQ handler re-enables interrupts
   (clears CPSR.I), nested IRQs can occur. The BIOS stub must handle
   stack discipline correctly. The current 6-register push/pop is
   sufficient for non-nested IRQs but may cause stack corruption with
   nested interrupts if SP_irq is not managed.

2. **Cascade timers with IRQ**: When a cascade timer overflows due to
   its parent overflowing, the IRQ should fire from within
   `timer_overflow_event`'s recursive call. The current implementation
   handles this (line 16: `tim.timer_overflow_event(num + 1)`).

3. **Timer enable timing**: On real hardware, there is a 2-cycle delay
   between writing TMCNT_H and the timer starting. The emulator starts
   the timer immediately upon write. This could cause off-by-2 cycle
   errors in IRQ timing tests.

4. **IF acknowledgment race**: If the user IRQ handler reads IF before
   the BIOS stub acknowledges it (in the proposed fix), the handler
   sees the pending bit. If the stub acknowledges first, the handler
   sees it cleared. The real BIOS acknowledges BEFORE calling the user
   handler, so the proposed stub order is correct.

5. **Multiple pending interrupts**: When multiple interrupts fire
   simultaneously, the BIOS handles them by priority (VBlank highest).
   The current `check_interrupts` calls `cpu.irq()` once, which
   handles the highest-priority pending interrupt. Lower-priority
   interrupts remain pending in IF and are handled after the first
   IRQ returns and re-enables interrupts.

6. **IME timing**: On real hardware, writing IME=1 takes effect after a
   short delay. The emulator applies it immediately via
   `schedule_interrupt_check()` on IME write
   (`src/dingbat/gba/interrupts.nim` line 35).
