# THUMB long branch with link (BL) (included by gba.nim)

proc thumb_long_branch_link*(cpu: CPU; instr: uint32) =
  let second_instr = bit(instr, 11)
  let offset       = bits_range(instr, 0, 10)
  if second_instr:
    let temp = cpu.r[15] - 2
    discard cpu.set_reg(15, cpu.r[14] + (offset shl 1))
    discard cpu.set_reg(14, temp or 1'u32)
  else:
    let off_signed = cast[int32](cast[int16](uint16(offset shl 5))) shr 5
    discard cpu.set_reg(14, uint32(int(cpu.r[15]) + (off_signed shl 12)))
    cpu.step_thumb()
