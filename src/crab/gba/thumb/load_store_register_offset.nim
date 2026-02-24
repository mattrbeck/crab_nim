# THUMB load/store with register offset (included by gba.nim)

proc thumb_load_store_register_offset*(cpu: CPU; instr: uint32) =
  let lb_and_bq = int(bits_range(instr, 10, 11))
  let ro        = int(bits_range(instr, 6, 8))
  let rb        = int(bits_range(instr, 3, 5))
  let rd        = int(bits_range(instr, 0, 2))
  let address   = cpu.r[rb] + cpu.r[ro]
  case lb_and_bq
  of 0b00:  # str
    cpu.gba.bus.write_word(address, cpu.r[rd])
  of 0b01:  # strb
    cpu.gba.bus[address] = uint8(cpu.r[rd])
  of 0b10:  # ldr
    discard cpu.set_reg(rd, cpu.gba.bus.read_word_rotate(address))
  of 0b11:  # ldrb
    discard cpu.set_reg(rd, uint32(cpu.gba.bus[address]))
  else: discard
  cpu.step_thumb()
