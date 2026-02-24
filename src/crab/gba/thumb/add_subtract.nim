# THUMB add/subtract (included by gba.nim)

proc thumb_add_subtract*(cpu: CPU; instr: uint32) =
  let imm_flag = bit(instr, 10)
  let sub      = bit(instr, 9)
  let imm      = bits_range(instr, 6, 8)
  let rs       = int(bits_range(instr, 3, 5))
  let rd       = int(bits_range(instr, 0, 2))
  let operand  = if imm_flag: imm else: cpu.r[int(imm)]
  if sub:
    discard cpu.set_reg(rd, cpu.sub(cpu.r[rs], operand, true))
  else:
    discard cpu.set_reg(rd, cpu.add(cpu.r[rs], operand, true))
  cpu.step_thumb()
