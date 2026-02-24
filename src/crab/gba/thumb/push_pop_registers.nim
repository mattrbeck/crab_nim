# THUMB push/pop registers (included by gba.nim)

proc thumb_push_pop_registers*(cpu: CPU; instr: uint32) =
  let pop  = bit(instr, 11)
  let pclr = bit(instr, 8)
  let list = bits_range(instr, 0, 7)
  var address = cpu.r[13]
  if pop:
    for idx in 0..7:
      if bit(list, idx):
        discard cpu.set_reg(idx, cpu.gba.bus.read_word(address))
        address += 4
    if pclr:
      discard cpu.set_reg(15, cpu.gba.bus.read_word(address))
      address += 4
  else:
    if pclr:
      address -= 4
      cpu.gba.bus.write_word(address, cpu.r[14])
    var idx = 7
    while idx >= 0:
      if bit(list, idx):
        address -= 4
        cpu.gba.bus.write_word(address, cpu.r[idx])
      dec idx
  discard cpu.set_reg(13, address)
  if not (pop and pclr): cpu.step_thumb()
