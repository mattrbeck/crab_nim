# THUMB ALU operations (included by gba.nim)

proc thumb_alu_operations*(cpu: CPU; instr: uint32) =
  let op = int(bits_range(instr, 6, 9))
  let rs = int(bits_range(instr, 3, 5))
  let rd = int(bits_range(instr, 0, 2))
  var barrel_shifter_carry_out = cpu.cpsr.carry
  var res: uint32
  case op
  of 0b0000: res = cpu.set_reg(rd, cpu.r[rd] and cpu.r[rs])
  of 0b0001: res = cpu.set_reg(rd, cpu.r[rd] xor cpu.r[rs])
  of 0b0010:
    res = cpu.set_reg(rd, cpu.lsl(cpu.r[rd], cpu.r[rs], addr barrel_shifter_carry_out))
    cpu.cpsr.carry = barrel_shifter_carry_out
  of 0b0011:
    res = cpu.set_reg(rd, cpu.lsr(cpu.r[rd], cpu.r[rs], false, addr barrel_shifter_carry_out))
    cpu.cpsr.carry = barrel_shifter_carry_out
  of 0b0100:
    res = cpu.set_reg(rd, cpu.asr(cpu.r[rd], cpu.r[rs], false, addr barrel_shifter_carry_out))
    cpu.cpsr.carry = barrel_shifter_carry_out
  of 0b0101: res = cpu.set_reg(rd, cpu.adc(cpu.r[rd], cpu.r[rs], set_conditions = true))
  of 0b0110: res = cpu.set_reg(rd, cpu.sbc(cpu.r[rd], cpu.r[rs], set_conditions = true))
  of 0b0111:
    res = cpu.set_reg(rd, cpu.ror(cpu.r[rd], cpu.r[rs], false, addr barrel_shifter_carry_out))
    cpu.cpsr.carry = barrel_shifter_carry_out
  of 0b1000: res = cpu.r[rd] and cpu.r[rs]
  of 0b1001: res = cpu.set_reg(rd, cpu.sub(0'u32, cpu.r[rs], set_conditions = true))
  of 0b1010: res = cpu.sub(cpu.r[rd], cpu.r[rs], set_conditions = true)
  of 0b1011: res = cpu.add(cpu.r[rd], cpu.r[rs], set_conditions = true)
  of 0b1100: res = cpu.set_reg(rd, cpu.r[rd] or cpu.r[rs])
  of 0b1101: res = cpu.set_reg(rd, cpu.r[rs] * cpu.r[rd])
  of 0b1110: res = cpu.set_reg(rd, cpu.r[rd] and not cpu.r[rs])
  of 0b1111: res = cpu.set_reg(rd, not cpu.r[rs])
  else: raise newException(Exception, "Invalid alu op: " & $op)
  cpu.set_neg_and_zero_flags(res)
  cpu.step_thumb()
