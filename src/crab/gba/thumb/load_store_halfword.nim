# THUMB load/store halfword (included by gba.nim)

proc thumb_load_store_halfword*(cpu: CPU; instr: uint32) =
  let load   = bit(instr, 11)
  let offset = bits_range(instr, 6, 10)
  let rb     = int(bits_range(instr, 3, 5))
  let rd     = int(bits_range(instr, 0, 2))
  let address = cpu.r[rb] + (offset shl 1)
  if load:
    discard cpu.set_reg(rd, cpu.gba.bus.read_half_rotate(address))
  else:
    cpu.gba.bus.write_half(address, uint16(cpu.r[rd]))
  cpu.step_thumb()
