# THUMB dispatcher and LUT builder (included by gba.nim)

proc thumb_execute*(cpu: CPU; instr: uint32) =
  cpu.thumb_lut[instr shr 8](instr)

proc thumb_unimplemented*(cpu: CPU; instr: uint32) =
  raise newException(Exception, "Unimplemented THUMB instruction: " & hex_str(uint16(instr)))

proc fill_thumb_lut*(cpu: CPU): seq[proc(instr: uint32) {.closure.}] =
  result = newSeq[proc(instr: uint32) {.closure.}](256)
  for idx in 0 ..< 256:
    let i = idx
    result[i] =
      if   (i and 0b11110000) == 0b11110000:
        proc(instr: uint32) {.closure.} = cpu.thumb_long_branch_link(instr)
      elif (i and 0b11111000) == 0b11100000:
        proc(instr: uint32) {.closure.} = cpu.thumb_unconditional_branch(instr)
      elif (i and 0b11111111) == 0b11011111:
        proc(instr: uint32) {.closure.} = cpu.thumb_software_interrupt(instr)
      elif (i and 0b11110000) == 0b11010000:
        proc(instr: uint32) {.closure.} = cpu.thumb_conditional_branch(instr)
      elif (i and 0b11110000) == 0b11000000:
        proc(instr: uint32) {.closure.} = cpu.thumb_multiple_load_store(instr)
      elif (i and 0b11110110) == 0b10110100:
        proc(instr: uint32) {.closure.} = cpu.thumb_push_pop_registers(instr)
      elif (i and 0b11111111) == 0b10110000:
        proc(instr: uint32) {.closure.} = cpu.thumb_add_offset_to_stack_pointer(instr)
      elif (i and 0b11110000) == 0b10100000:
        proc(instr: uint32) {.closure.} = cpu.thumb_load_address(instr)
      elif (i and 0b11110000) == 0b10010000:
        proc(instr: uint32) {.closure.} = cpu.thumb_sp_relative_load_store(instr)
      elif (i and 0b11110000) == 0b10000000:
        proc(instr: uint32) {.closure.} = cpu.thumb_load_store_halfword(instr)
      elif (i and 0b11100000) == 0b01100000:
        proc(instr: uint32) {.closure.} = cpu.thumb_load_store_immediate_offset(instr)
      elif (i and 0b11110010) == 0b01010010:
        proc(instr: uint32) {.closure.} = cpu.thumb_load_store_sign_extended(instr)
      elif (i and 0b11110010) == 0b01010000:
        proc(instr: uint32) {.closure.} = cpu.thumb_load_store_register_offset(instr)
      elif (i and 0b11111000) == 0b01001000:
        proc(instr: uint32) {.closure.} = cpu.thumb_pc_relative_load(instr)
      elif (i and 0b11111100) == 0b01000100:
        proc(instr: uint32) {.closure.} = cpu.thumb_high_reg_branch_exchange(instr)
      elif (i and 0b11111100) == 0b01000000:
        proc(instr: uint32) {.closure.} = cpu.thumb_alu_operations(instr)
      elif (i and 0b11100000) == 0b00100000:
        proc(instr: uint32) {.closure.} = cpu.thumb_move_compare_add_subtract(instr)
      elif (i and 0b11111000) == 0b00011000:
        proc(instr: uint32) {.closure.} = cpu.thumb_add_subtract(instr)
      elif (i and 0b11100000) == 0b00000000:
        proc(instr: uint32) {.closure.} = cpu.thumb_move_shifted_register(instr)
      else:
        proc(instr: uint32) {.closure.} = cpu.thumb_unimplemented(instr)
