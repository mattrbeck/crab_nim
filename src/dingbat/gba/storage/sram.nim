# SRAM storage (included by gba.nim)

proc new_sram*(): SRAM =
  result = SRAM()
  result.memory = newSeq[byte](storage_bytes(stSRAM))
  for b in result.memory.mitems: b = 0xFF

method `[]`*(st: SRAM; address: uint32): uint8 =
  st.memory[address and 0x7FFF'u32]

method `[]=`*(st: SRAM; address: uint32; value: uint8) =
  st.memory[address and 0x7FFF'u32] = value
  st.dirty = true
