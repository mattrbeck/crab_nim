# THUMB conditional branch (included by gba.nim)

proc thumb_conditional_branch*(cpu: CPU; instr: uint32) =
  let cond        = bits_range(instr, 8, 11)
  let offset      = cast[int32](cast[int8](uint8(bits_range(instr, 0, 7))))
  let branch_dest = uint32(int(cpu.r[15]) + offset * 2)
  cpu.analyze_loop(branch_dest, cpu.r[15] - 4)
  if cpu.check_cond(cond):
    discard cpu.set_reg(15, branch_dest)
  else:
    cpu.step_thumb()
