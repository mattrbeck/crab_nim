# ARM multiply (MUL/MLA) (included by gba.nim)

proc arm_multiply*(cpu: CPU; instr: uint32) =
  let accumulate    = bit(instr, 21)
  let set_conditions = bit(instr, 20)
  let rd            = int(bits_range(instr, 16, 19))
  let rn            = int(bits_range(instr, 12, 15))
  let rs            = int(bits_range(instr, 8, 11))
  let rm            = int(bits_range(instr, 0, 3))
  let acc: uint32   = if accumulate: cpu.r[rn] else: 0'u32
  discard cpu.set_reg(rd, cpu.r[rm] * cpu.r[rs] + acc)
  if set_conditions: cpu.set_neg_and_zero_flags(cpu.r[rd])
  if rd != 15: cpu.step_arm()
