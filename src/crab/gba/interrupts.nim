# Interrupts implementation (included by gba.nim)

proc new_interrupts*(gba: GBA): Interrupts =
  result = Interrupts(gba: gba)
  result.reg_ie = InterruptReg(value: 0)
  result.reg_if = InterruptReg(value: 0)
  result.ime = false

proc schedule_interrupt_check*(intr: Interrupts) =
  let g = intr.gba
  g.scheduler.schedule(0, proc() {.closure.} =
    if (intr.reg_ie.value and intr.reg_if.value) != 0:
      g.cpu.halted = false
      if intr.ime:
        g.cpu.irq()
  , etInterrupts)

proc `[]`*(intr: Interrupts; io_addr: uint32): uint8 =
  case io_addr
  of 0x200: uint8(intr.reg_ie.value and 0xFF)
  of 0x201: uint8((intr.reg_ie.value shr 8) and 0xFF)
  of 0x202: uint8(intr.reg_if.value and 0xFF)
  of 0x203: uint8((intr.reg_if.value shr 8) and 0xFF)
  of 0x208: (if intr.ime: 1'u8 else: 0'u8)
  of 0x209: 0'u8
  else: raise newException(Exception, "Unimplemented interrupts read addr: " & hex_str(uint8(io_addr)))

proc `[]=`*(intr: Interrupts; io_addr: uint32; value: uint8) =
  case io_addr
  of 0x200: intr.reg_ie.value = (intr.reg_ie.value and 0xFF00'u16) or uint16(value)
  of 0x201: intr.reg_ie.value = (intr.reg_ie.value and 0x00FF'u16) or (uint16(value) shl 8)
  of 0x202: intr.reg_if.value = intr.reg_if.value and not uint16(value)
  of 0x203: intr.reg_if.value = intr.reg_if.value and not (uint16(value) shl 8)
  of 0x208: intr.ime = bit(value, 0)
  of 0x209: discard
  else: raise newException(Exception, "Unimplemented interrupts write addr: " & hex_str(uint8(io_addr)) & " val: " & hex_str(value))
  intr.schedule_interrupt_check()
