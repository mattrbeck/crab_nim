# ARM single data swap (SWP/SWPB) (included by gba.nim)

proc arm_single_data_swap*(cpu: CPU; instr: uint32) =
  let byte_quantity = bit(instr, 22)
  let rn            = int(bits_range(instr, 16, 19))
  let rd            = int(bits_range(instr, 12, 15))
  let rm            = int(bits_range(instr, 0, 3))
  if byte_quantity:
    let tmp = cpu.gba.bus[cpu.r[rn]]
    cpu.gba.bus[cpu.r[rn]] = uint8(cpu.r[rm])
    discard cpu.set_reg(rd, uint32(tmp))
  else:
    let tmp = cpu.gba.bus.read_word_rotate(cpu.r[rn])
    cpu.gba.bus.write_word(cpu.r[rn], cpu.r[rm])
    discard cpu.set_reg(rd, tmp)
  if rd != 15: cpu.step_arm()
