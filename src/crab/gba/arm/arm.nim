# ARM dispatcher and LUT builder (included by gba.nim)

proc arm_execute*(cpu: CPU; instr: uint32) =
  if cpu.check_cond(bits_range(instr, 28, 31)):
    let hash = (instr shr 16 and 0x0FF0'u32) or (instr shr 4 and 0xF'u32)
    cpu.lut[hash](instr)
  else:
    log("Skipping instruction, cond: " & hex_str(uint8(instr shr 28)))
    cpu.step_arm()

proc arm_unimplemented*(cpu: CPU; instr: uint32) =
  cpu.und()
  cpu.step_arm()

proc arm_unused*(cpu: CPU; instr: uint32) =
  cpu.und()
  cpu.step_arm()

proc rotate_register*(cpu: CPU; instr: uint32; carry_out: ptr bool; allow_register_shifts: bool): uint32 =
  let reg        = int(bits_range(instr, 0, 3))
  let shift_type = int(bits_range(instr, 5, 6))
  let immediate  = not (allow_register_shifts and bit(instr, 4))
  var shift_amount: uint32
  if immediate:
    shift_amount = bits_range(instr, 7, 11)
  else:
    let shift_register = int(bits_range(instr, 8, 11))
    shift_amount = cpu.r[shift_register] and 0xFF'u32
  case shift_type
  of 0b00: cpu.lsl(cpu.r[reg], shift_amount, carry_out)
  of 0b01: cpu.lsr(cpu.r[reg], shift_amount, immediate, carry_out)
  of 0b10: cpu.asr(cpu.r[reg], shift_amount, immediate, carry_out)
  of 0b11: cpu.ror(cpu.r[reg], shift_amount, immediate, carry_out)
  else: raise newException(Exception, "Impossible shift type: " & hex_str(uint8(shift_type)))

proc immediate_offset*(cpu: CPU; instr: uint32; carry_out: ptr bool): uint32 =
  let rotate = bits_range(instr, 8, 11)
  let imm    = bits_range(instr, 0, 7)
  cpu.ror(imm, rotate shl 1, false, carry_out)

proc fill_lut*(cpu: CPU): seq[proc(instr: uint32) {.closure.}] =
  result = newSeq[proc(instr: uint32) {.closure.}](4096)
  for idx in 0 ..< 4096:
    let i = idx
    result[i] =
      if   (i and 0b111100000000) == 0b111100000000:
        proc(instr: uint32) {.closure.} = cpu.arm_software_interrupt(instr)
      elif (i and 0b111100000001) == 0b111000000001:
        proc(instr: uint32) {.closure.} = cpu.arm_unimplemented(instr)  # coprocessor
      elif (i and 0b111000000000) == 0b110000000000:
        proc(instr: uint32) {.closure.} = cpu.arm_unimplemented(instr)  # coprocessor data transfer
      elif (i and 0b111000000000) == 0b101000000000:
        proc(instr: uint32) {.closure.} = cpu.arm_branch(instr)
      elif (i and 0b111000000000) == 0b100000000000:
        proc(instr: uint32) {.closure.} = cpu.arm_block_data_transfer(instr)
      elif (i and 0b111000000001) == 0b011000000001:
        proc(instr: uint32) {.closure.} = cpu.arm_unimplemented(instr)  # undefined
      elif (i and 0b110000000000) == 0b010000000000:
        proc(instr: uint32) {.closure.} = cpu.arm_single_data_transfer(instr)
      elif (i and 0b111111111111) == 0b000100100001:
        proc(instr: uint32) {.closure.} = cpu.arm_branch_exchange(instr)
      elif (i and 0b111110111111) == 0b000100001001:
        proc(instr: uint32) {.closure.} = cpu.arm_single_data_swap(instr)
      elif (i and 0b111110001111) == 0b000010001001:
        proc(instr: uint32) {.closure.} = cpu.arm_multiply_long(instr)
      elif (i and 0b111111001111) == 0b000000001001:
        proc(instr: uint32) {.closure.} = cpu.arm_multiply(instr)
      elif (i and 0b111001001001) == 0b000001001001:
        proc(instr: uint32) {.closure.} = cpu.arm_halfword_data_transfer_immediate(instr)
      elif (i and 0b111001001001) == 0b000000001001:
        proc(instr: uint32) {.closure.} = cpu.arm_halfword_data_transfer_register(instr)
      elif (i and 0b110110010000) == 0b000100000000:
        proc(instr: uint32) {.closure.} = cpu.arm_psr_transfer(instr)
      elif (i and 0b110000000000) == 0b000000000000:
        proc(instr: uint32) {.closure.} = cpu.arm_data_processing(instr)
      else:
        proc(instr: uint32) {.closure.} = cpu.arm_unused(instr)
