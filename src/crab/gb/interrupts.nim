# GB Interrupts (included by gb.nim)

const
  INT_VBLANK* = 0x0040'u16
  INT_STAT*   = 0x0048'u16
  INT_TIMER*  = 0x0050'u16
  INT_SERIAL* = 0x0058'u16
  INT_JOYPAD* = 0x0060'u16
  INT_NONE*   = 0x0000'u16

proc new_gb_interrupts*(): GbInterrupts =
  GbInterrupts()

proc highest_priority*(irq: GbInterrupts): uint16 =
  if irq.vblank_interrupt   and irq.vblank_enabled:   INT_VBLANK
  elif irq.lcd_stat_interrupt and irq.lcd_stat_enabled: INT_STAT
  elif irq.timer_interrupt    and irq.timer_enabled:    INT_TIMER
  elif irq.serial_interrupt   and irq.serial_enabled:   INT_SERIAL
  elif irq.joypad_interrupt   and irq.joypad_enabled:   INT_JOYPAD
  else: INT_NONE

proc clear_interrupt*(irq: GbInterrupts; line: uint16) =
  case line
  of INT_VBLANK: irq.vblank_interrupt    = false
  of INT_STAT:   irq.lcd_stat_interrupt  = false
  of INT_TIMER:  irq.timer_interrupt     = false
  of INT_SERIAL: irq.serial_interrupt    = false
  of INT_JOYPAD: irq.joypad_interrupt    = false
  else: discard

proc irq_read*(irq: GbInterrupts; idx: int): uint8 =
  case idx
  of 0xFF0F:
    0xE0'u8 or
    (if irq.joypad_interrupt:   0x10'u8 else: 0'u8) or
    (if irq.serial_interrupt:   0x08'u8 else: 0'u8) or
    (if irq.timer_interrupt:    0x04'u8 else: 0'u8) or
    (if irq.lcd_stat_interrupt: 0x02'u8 else: 0'u8) or
    (if irq.vblank_interrupt:   0x01'u8 else: 0'u8)
  of 0xFFFF:
    irq.top_3_ie_bits or
    (if irq.joypad_enabled:   0x10'u8 else: 0'u8) or
    (if irq.serial_enabled:   0x08'u8 else: 0'u8) or
    (if irq.timer_enabled:    0x04'u8 else: 0'u8) or
    (if irq.lcd_stat_enabled: 0x02'u8 else: 0'u8) or
    (if irq.vblank_enabled:   0x01'u8 else: 0'u8)
  else: 0xFF'u8

proc interrupt_ready*(irq: GbInterrupts): bool =
  (irq_read(irq, 0xFF0F) and irq_read(irq, 0xFFFF) and 0x1F) != 0

proc irq_write*(irq: GbInterrupts; idx: int; val: uint8) =
  case idx
  of 0xFF0F:
    irq.vblank_interrupt    = (val and 0x01) != 0
    irq.lcd_stat_interrupt  = (val and 0x02) != 0
    irq.timer_interrupt     = (val and 0x04) != 0
    irq.serial_interrupt    = (val and 0x08) != 0
    irq.joypad_interrupt    = (val and 0x10) != 0
  of 0xFFFF:
    irq.top_3_ie_bits    = val and 0xE0
    irq.vblank_enabled   = (val and 0x01) != 0
    irq.lcd_stat_enabled = (val and 0x02) != 0
    irq.timer_enabled    = (val and 0x04) != 0
    irq.serial_enabled   = (val and 0x08) != 0
    irq.joypad_enabled   = (val and 0x10) != 0
  else: discard
