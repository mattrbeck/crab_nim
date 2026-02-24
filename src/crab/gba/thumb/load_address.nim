# THUMB load address (included by gba.nim)

proc thumb_load_address*(cpu: CPU; instr: uint32) =
  let source = bit(instr, 11)
  let rd     = int(bits_range(instr, 8, 10))
  let word   = bits_range(instr, 0, 7)
  let imm    = word shl 2
  cpu.r[rd] = (if source: cpu.r[13] else: cpu.r[15] and not 2'u32) + imm
  cpu.step_thumb()
