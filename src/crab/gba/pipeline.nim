# Pipeline implementation (included by gba.nim)

proc push*(p: var Pipeline; instr: uint32) =
  assert p.size < 2, "Pushing to full pipeline"
  let address = (p.pos + p.size) and 1
  p.buffer[address] = instr
  inc p.size

proc shift*(p: var Pipeline): uint32 =
  dec p.size
  result = p.buffer[p.pos]
  p.pos = (p.pos + 1) and 1

proc peek*(p: Pipeline): uint32 =
  p.buffer[p.pos]

proc clear*(p: var Pipeline) =
  p.size = 0
