# ARM block data transfer (LDM/STM) (included by gba.nim)

proc arm_block_data_transfer*(cpu: CPU; instr: uint32) =
  let pre_address = bit(instr, 24)
  let add         = bit(instr, 23)
  let s_bit       = bit(instr, 22)
  let write_back  = bit(instr, 21)
  let load        = bit(instr, 20)
  let rn          = int(bits_range(instr, 16, 19))
  var list        = bits_range(instr, 0, 15)
  var saved_mode: uint32 = 0
  if s_bit:
    if bit(list, 15):
      raise newException(Exception, "todo: handle cases with r15 in list")
    saved_mode = cpu.cpsr.mode
    cpu.switch_mode(modeUSR)
  var address   = cpu.r[rn]
  var bits_set  = count_set_bits(list)
  if bits_set == 0:
    bits_set = 16
    list = 0x8000'u32
  let final_addr = uint32(int(address) + bits_set * (if add: 4 else: -4))
  if add:
    if pre_address: address += 4
  else:
    address = final_addr
    if not pre_address: address += 4
  var first_transfer = false
  for idx in 0..15:
    if bit(list, idx):
      if load:
        discard cpu.set_reg(idx, cpu.gba.bus.read_word(address))
      else:
        cpu.gba.bus.write_word(address, cpu.r[idx])
        if idx == 15:
          cpu.gba.bus.write_word(address, cpu.gba.bus.read_word(address) + 4)
      address += 4
      if write_back and not first_transfer and not (load and bit(list, rn)):
        discard cpu.set_reg(rn, final_addr)
      first_transfer = true
  if s_bit:
    cpu.switch_mode(CpuMode(saved_mode))
  if not (load and bit(list, 15)): cpu.step_arm()
