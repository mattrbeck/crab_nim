# Flash storage implementation (included by gba.nim)

const
  FLASH_CMD_ENTER_IDENT*:   uint8 = 0x90
  FLASH_CMD_EXIT_IDENT*:    uint8 = 0xF0
  FLASH_CMD_PREPARE_ERASE*: uint8 = 0x80
  FLASH_CMD_ERASE_ALL*:     uint8 = 0x10
  FLASH_CMD_ERASE_CHUNK*:   uint8 = 0x30
  FLASH_CMD_PREPARE_WRITE*: uint8 = 0xA0
  FLASH_CMD_SET_BANK*:      uint8 = 0xB0

proc new_flash*(flash_type: StorageType): Flash =
  let mem_size = storage_bytes(flash_type)
  result = Flash(
    flash_type: flash_type,
    state: {fsReady},
    bank: 0,
  )
  result.memory = newSeq[byte](mem_size)
  for i in 0 ..< result.memory.len:
    result.memory[i] = 0xFF
  result.id = case flash_type
    of stFLASH1M: 0x1362'u16  # Sanyo
    else:         0x1B32'u16  # Panasonic

method `[]`*(fl: Flash; address: uint32): uint8 =
  let a = address and 0xFFFF'u32
  if fsIdentification in fl.state and a <= 1:
    uint8((fl.id shr (8 * a)) and 0xFF)
  else:
    fl.memory[0x10000 * int(fl.bank) + int(a)]

method `[]=`*(fl: Flash; address: uint32; value: uint8) =
  let a = address and 0xFFFF'u32
  if fsPrepareWrite in fl.state:
    fl.memory[0x10000 * int(fl.bank) + int(a)] = fl.memory[0x10000 * int(fl.bank) + int(a)] and value
    fl.dirty = true
    fl.state.excl(fsPrepareWrite)
  elif fsSetBank in fl.state:
    fl.bank = value and 1
    fl.state.excl(fsSetBank)
  elif fsReady in fl.state:
    if a == 0x5555 and value == 0xAA:
      fl.state.excl(fsReady)
      fl.state.incl(fsCmd1)
  elif fsCmd1 in fl.state:
    if a == 0x2AAA and value == 0x55:
      fl.state.excl(fsCmd1)
      fl.state.incl(fsCmd2)
  elif fsCmd2 in fl.state:
    if a == 0x5555:
      case value
      of FLASH_CMD_ENTER_IDENT:
        fl.state.incl(fsIdentification)
      of FLASH_CMD_EXIT_IDENT:
        fl.state.excl(fsIdentification)
      of FLASH_CMD_PREPARE_ERASE:
        fl.state.incl(fsPrepareErase)
      of FLASH_CMD_ERASE_ALL:
        if fsPrepareErase in fl.state:
          for i in 0 ..< fl.memory.len:
            fl.memory[i] = 0xFF
          fl.dirty = true
          fl.state.excl(fsPrepareErase)
      of FLASH_CMD_PREPARE_WRITE:
        fl.state.incl(fsPrepareWrite)
      of FLASH_CMD_SET_BANK:
        if fl.flash_type == stFLASH1M:
          fl.state.incl(fsSetBank)
      else:
        echo "Unsupported flash command ", hex_str(value)
    elif fsPrepareErase in fl.state and (a and 0x0FFF'u32) == 0 and value == FLASH_CMD_ERASE_CHUNK:
      for i in 0 ..< 0x1000:
        fl.memory[0x10000 * int(fl.bank) + int(a) + i] = 0xFF
      fl.dirty = true
      fl.state.excl(fsPrepareErase)
    fl.state.excl(fsCmd2)
    fl.state.incl(fsReady)
