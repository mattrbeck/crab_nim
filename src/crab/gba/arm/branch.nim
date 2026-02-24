# ARM branch (B/BL) (included by gba.nim)

proc arm_branch*(cpu: CPU; instr: uint32) =
  let link   = bit(instr, 24)
  let offset = cast[int32](bits_range(instr, 0, 23) shl 8) shr 6
  if link: discard cpu.set_reg(14, cpu.r[15] - 4)
  discard cpu.set_reg(15, uint32(int(cpu.r[15]) + offset))
