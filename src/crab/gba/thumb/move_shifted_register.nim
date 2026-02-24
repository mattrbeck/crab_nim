# THUMB move shifted register (LSL/LSR/ASR) (included by gba.nim)

proc thumb_move_shifted_register*(cpu: CPU; instr: uint32) =
  let op     = int(bits_range(instr, 11, 12))
  let offset = bits_range(instr, 6, 10)
  let rs     = int(bits_range(instr, 3, 5))
  let rd     = int(bits_range(instr, 0, 2))
  var carry_out = cpu.cpsr.carry
  case op
  of 0b00: discard cpu.set_reg(rd, cpu.lsl(cpu.r[rs], offset, addr carry_out))
  of 0b01: discard cpu.set_reg(rd, cpu.lsr(cpu.r[rs], offset, true, addr carry_out))
  of 0b10: discard cpu.set_reg(rd, cpu.asr(cpu.r[rs], offset, true, addr carry_out))
  of 0b11: discard  # encodes thumb add/subtract
  else: raise newException(Exception, "Invalid shifted register op: " & $op)
  cpu.set_neg_and_zero_flags(cpu.r[rd])
  cpu.cpsr.carry = carry_out
  cpu.step_thumb()
