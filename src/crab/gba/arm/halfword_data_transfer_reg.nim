# ARM halfword data transfer (register offset) (included by gba.nim)

proc arm_halfword_data_transfer_register*(cpu: CPU; instr: uint32) =
  let pre_address = bit(instr, 24)
  let add         = bit(instr, 23)
  let write_back  = bit(instr, 21)
  let load        = bit(instr, 20)
  let rn          = int(bits_range(instr, 16, 19))
  let rd          = int(bits_range(instr, 12, 15))
  let sh          = int(bits_range(instr, 5, 6))
  let rm          = int(bits_range(instr, 0, 3))
  var address     = cpu.r[rn]
  let offset      = cpu.r[rm]
  if pre_address:
    if add: address += offset else: address -= offset
  case sh
  of 0b00:
    raise newException(Exception, "HalfwordDataTransferReg swp " & hex_str(instr))
  of 0b01:  # ldrh/strh
    if load:
      discard cpu.set_reg(rd, cpu.gba.bus.read_half_rotate(address))
    else:
      cpu.gba.bus.write_half(address, uint16(cpu.r[rd] and 0xFFFF'u32))
      if rd == 15:
        cpu.gba.bus.write_half(address, uint16(cpu.gba.bus.read_half(address)) + 4)
  of 0b10:  # ldrsb
    discard cpu.set_reg(rd, uint32(cast[int32](cast[int8](cpu.gba.bus[address]))))
  of 0b11:  # ldrsh
    discard cpu.set_reg(rd, cpu.gba.bus.read_half_signed(address))
  else:
    raise newException(Exception, "Invalid halfword data transfer reg op: " & $sh)
  if not pre_address:
    if add: address += offset else: address -= offset
  if (write_back or not pre_address) and (rd != rn or not load):
    discard cpu.set_reg(rn, address)
  if not (load and rd == 15): cpu.step_arm()
