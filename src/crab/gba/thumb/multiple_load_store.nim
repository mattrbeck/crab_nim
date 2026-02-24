# THUMB multiple load/store (LDMIA/STMIA) (included by gba.nim)

proc thumb_multiple_load_store*(cpu: CPU; instr: uint32) =
  let load    = bit(instr, 11)
  let rb      = int(bits_range(instr, 8, 10))
  let list    = bits_range(instr, 0, 7)
  var address = cpu.r[rb]
  if list != 0:
    let final_addr = 4'u32 * uint32(count_set_bits(list)) + address
    if load:  # ldmia
      cpu.r[rb] = final_addr  # writeback immediately
      for idx in 0..7:
        if bit(list, idx):
          discard cpu.set_reg(idx, cpu.gba.bus.read_word(address))
          address += 4
    else:  # stmia
      var first_transfer = false
      for idx in 0..7:
        if bit(list, idx):
          cpu.gba.bus.write_word(address, cpu.r[idx])
          address += 4
          if not first_transfer:
            cpu.r[rb] = final_addr  # writeback after first transfer
          first_transfer = true
  else:  # empty list edge case
    if load:
      discard cpu.set_reg(15, cpu.gba.bus.read_word(address))
    else:
      cpu.gba.bus.write_word(address, cpu.r[15] + 2)
    discard cpu.set_reg(rb, address + 0x40'u32)
  if not (list == 0 and load): cpu.step_thumb()
