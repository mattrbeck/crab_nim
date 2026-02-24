# ARM single data transfer (LDR/STR) (included by gba.nim)

proc arm_single_data_transfer*(cpu: CPU; instr: uint32) =
  let imm_flag      = bit(instr, 25)
  let pre_addressing = bit(instr, 24)
  let add_offset    = bit(instr, 23)
  let byte_quantity = bit(instr, 22)
  let write_back    = bit(instr, 21)
  let load          = bit(instr, 20)
  let rn            = int(bits_range(instr, 16, 19))
  let rd            = int(bits_range(instr, 12, 15))
  var carry_out = false
  let offset =
    if imm_flag:
      cpu.rotate_register(bits_range(instr, 0, 11), addr carry_out, allow_register_shifts = false)
    else:
      bits_range(instr, 0, 11)
  var address = cpu.r[rn]
  if pre_addressing:
    if add_offset: address += offset
    else:          address -= offset
  if load:
    if byte_quantity:
      discard cpu.set_reg(rd, uint32(cpu.gba.bus[address]))
    else:
      discard cpu.set_reg(rd, cpu.gba.bus.read_word_rotate(address))
  else:
    if byte_quantity:
      cpu.gba.bus[address] = uint8(cpu.r[rd])
    else:
      cpu.gba.bus.write_word(address, cpu.r[rd])
    if rd == 15:
      cpu.gba.bus.write_word(address, cpu.gba.bus.read_word(address) + 4)
  if not pre_addressing:
    if add_offset: address += offset
    else:          address -= offset
  if (write_back or not pre_addressing) and (rd != rn or not load):
    discard cpu.set_reg(rn, address)
  if not (load and rd == 15): cpu.step_arm()
