# THUMB hi register operations / branch exchange (included by gba.nim)

proc thumb_high_reg_branch_exchange*(cpu: CPU; instr: uint32) =
  let op = int(bits_range(instr, 8, 9))
  let h1 = bit(instr, 7)
  let h2 = bit(instr, 6)
  var rs = int(bits_range(instr, 3, 5))
  var rd = int(bits_range(instr, 0, 2))
  if h1: rd += 8
  if h2: rs += 8
  case op
  of 0b00: discard cpu.set_reg(rd, cpu.add(cpu.r[rd], cpu.r[rs], false))
  of 0b01: discard cpu.sub(cpu.r[rd], cpu.r[rs], true)
  of 0b10: discard cpu.set_reg(rd, cpu.r[rs])
  of 0b11:
    if bit(cpu.r[rs], 0):
      discard cpu.set_reg(15, cpu.r[rs])
    else:
      cpu.cpsr.thumb = false
      discard cpu.set_reg(15, cpu.r[rs])
  else: discard
  if rd != 15 and op != 0b11: cpu.step_thumb()
