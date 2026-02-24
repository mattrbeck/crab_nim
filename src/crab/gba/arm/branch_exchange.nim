# ARM branch and exchange (BX) (included by gba.nim)

proc arm_branch_exchange*(cpu: CPU; instr: uint32) =
  let address = cpu.r[int(bits_range(instr, 0, 3))]
  cpu.cpsr.thumb = bit(address, 0)
  discard cpu.set_reg(15, address)
