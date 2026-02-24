# THUMB move/compare/add/subtract immediate (included by gba.nim)

proc thumb_move_compare_add_subtract*(cpu: CPU; instr: uint32) =
  let op     = int(bits_range(instr, 11, 12))
  let rd     = int(bits_range(instr, 8, 10))
  let offset = bits_range(instr, 0, 7)
  case op
  of 0b00:
    discard cpu.set_reg(rd, offset)
    cpu.set_neg_and_zero_flags(cpu.r[rd])
  of 0b01: discard cpu.sub(cpu.r[rd], offset, true)
  of 0b10: discard cpu.set_reg(rd, cpu.add(cpu.r[rd], offset, true))
  of 0b11: discard cpu.set_reg(rd, cpu.sub(cpu.r[rd], offset, true))
  else: raise newException(Exception, "Invalid move/compare/add/subtract op: " & $op)
  cpu.step_thumb()
