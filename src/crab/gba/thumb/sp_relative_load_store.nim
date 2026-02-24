# THUMB SP-relative load/store (included by gba.nim)

proc thumb_sp_relative_load_store*(cpu: CPU; instr: uint32) =
  let load    = bit(instr, 11)
  let rd      = int(bits_range(instr, 8, 10))
  let word    = bits_range(instr, 0, 7)
  let address = cpu.r[13] + (word shl 2)
  if load:
    discard cpu.set_reg(rd, cpu.gba.bus.read_word_rotate(address))
  else:
    cpu.gba.bus.write_word(address, cpu.r[rd])
  cpu.step_thumb()
