# THUMB add offset to stack pointer (included by gba.nim)

proc thumb_add_offset_to_stack_pointer*(cpu: CPU; instr: uint32) =
  let sign   = bit(instr, 7)
  let offset = bits_range(instr, 0, 6)
  if sign:
    discard cpu.set_reg(13, cpu.r[13] - (offset shl 2))
  else:
    discard cpu.set_reg(13, cpu.r[13] + (offset shl 2))
  cpu.step_thumb()
