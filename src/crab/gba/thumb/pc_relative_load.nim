# THUMB PC-relative load (included by gba.nim)

proc thumb_pc_relative_load*(cpu: CPU; instr: uint32) =
  let imm = bits_range(instr, 0, 7)
  let rd  = int(bits_range(instr, 8, 10))
  discard cpu.set_reg(rd, cpu.gba.bus.read_word((cpu.r[15] and not 2'u32) + (imm shl 2)))
  cpu.step_thumb()
