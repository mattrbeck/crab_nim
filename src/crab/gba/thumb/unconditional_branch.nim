# THUMB unconditional branch (B) (included by gba.nim)

proc thumb_unconditional_branch*(cpu: CPU; instr: uint32) =
  let offset = bits_range(instr, 0, 10)
  let off_signed = cast[int32](cast[int16](uint16(offset shl 5))) shr 4
  discard cpu.set_reg(15, uint32(int(cpu.r[15]) + off_signed))
