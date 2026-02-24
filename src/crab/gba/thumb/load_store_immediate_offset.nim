# THUMB load/store with immediate offset (included by gba.nim)

proc thumb_load_store_immediate_offset*(cpu: CPU; instr: uint32) =
  let bq_and_load = int(bits_range(instr, 11, 12))
  let offset      = bits_range(instr, 6, 10)
  let rb          = int(bits_range(instr, 3, 5))
  let rd          = int(bits_range(instr, 0, 2))
  let base_addr   = cpu.r[rb]
  case bq_and_load
  of 0b00:  # str
    cpu.gba.bus.write_word(base_addr + (offset shl 2), cpu.r[rd])
  of 0b01:  # ldr
    discard cpu.set_reg(rd, cpu.gba.bus.read_word_rotate(base_addr + (offset shl 2)))
  of 0b10:  # strb
    cpu.gba.bus[base_addr + offset] = uint8(cpu.r[rd])
  of 0b11:  # ldrb
    discard cpu.set_reg(rd, uint32(cpu.gba.bus[base_addr + offset]))
  else: discard
  cpu.step_thumb()
