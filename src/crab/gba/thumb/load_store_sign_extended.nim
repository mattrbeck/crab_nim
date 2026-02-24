# THUMB load/store sign-extended byte/halfword (included by gba.nim)

proc thumb_load_store_sign_extended*(cpu: CPU; instr: uint32) =
  let hs      = int(bits_range(instr, 10, 11))
  let ro      = int(bits_range(instr, 6, 8))
  let rb      = int(bits_range(instr, 3, 5))
  let rd      = int(bits_range(instr, 0, 2))
  let address = cpu.r[rb] + cpu.r[ro]
  case hs
  of 0b00:  # strh
    cpu.gba.bus.write_half(address, uint16(cpu.r[rd]))
  of 0b01:  # ldsb
    discard cpu.set_reg(rd, uint32(cast[int32](cast[int8](cpu.gba.bus[address]))))
  of 0b10:  # ldrh
    discard cpu.set_reg(rd, cpu.gba.bus.read_half_rotate(address))
  of 0b11:  # ldsh
    discard cpu.set_reg(rd, cpu.gba.bus.read_half_signed(address))
  else:
    raise newException(Exception, "Invalid load/store sign extended: " & $hs)
  cpu.step_thumb()
