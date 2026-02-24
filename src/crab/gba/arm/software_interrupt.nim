# ARM software interrupt (SWI) (included by gba.nim)

proc arm_software_interrupt*(cpu: CPU; instr: uint32) =
  let lr = cpu.r[15] - 4
  cpu.switch_mode(modeSVC)
  discard cpu.set_reg(14, lr)
  cpu.cpsr.irq_disable = true
  discard cpu.set_reg(15, 0x08'u32)
