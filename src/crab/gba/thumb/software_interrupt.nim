# THUMB software interrupt (SWI) (included by gba.nim)

proc thumb_software_interrupt*(cpu: CPU; instr: uint32) =
  let lr = cpu.r[15] - 2
  cpu.switch_mode(modeSVC)
  discard cpu.set_reg(14, lr)
  cpu.cpsr.irq_disable = true
  cpu.cpsr.thumb = false
  discard cpu.set_reg(15, 0x08'u32)
