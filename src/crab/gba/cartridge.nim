# Cartridge implementation (included by gba.nim)

proc new_cartridge*(rom_path: string): Cartridge =
  result = Cartridge()
  # Allocate 32 MB of ROM space and fill with the open-bus pattern.
  result.rom = newSeq[byte](0x02000000)
  for a in 0 ..< result.rom.len:
    let oob = 0xFFFF'u32 and (uint32(a) shr 1)
    result.rom[a] = uint8(oob shr (8 * (a and 1)))
  # Read actual ROM data.
  let f = open(rom_path, fmRead)
  discard f.readBytes(result.rom, 0, result.rom.len)
  f.close()
  # Handle improperly-dumped ROMs (non-power-of-two sizes).
  let sz = getFileSize(rom_path)
  if count_set_bits(sz) != 1:
    let last_bit = last_set_bit(sz)
    let next_pow = 1 shl (last_bit + 1)
    for i in sz ..< next_pow:
      result.rom[i] = 0

proc title*(cart: Cartridge): string =
  result = newString(12)
  for i in 0 ..< 12:
    result[i] = char(cart.rom[0x0A0 + i])
