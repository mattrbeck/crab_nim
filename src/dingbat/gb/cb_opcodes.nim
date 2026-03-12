# GB SM83 CPU CB-prefixed opcodes (included by gb.nim)

# ---------------------------------------------------------------------------
# CB rotate/shift helper procs
# ---------------------------------------------------------------------------

proc cb_rlc(cpu: GbCpu; val: uint8): uint8 =
  cpu.fc = (val shr 7) != 0
  result = (val shl 1) or (val shr 7)
  cpu.fz = result == 0; cpu.fn = false; cpu.fh = false

proc cb_rrc(cpu: GbCpu; val: uint8): uint8 =
  cpu.fc = (val and 1) != 0
  result = (val shr 1) or (val shl 7)
  cpu.fz = result == 0; cpu.fn = false; cpu.fh = false

proc cb_rl(cpu: GbCpu; val: uint8): uint8 =
  let old_c = cpu.fc
  cpu.fc = (val shr 7) != 0
  result = (val shl 1) or (if old_c: 1'u8 else: 0'u8)
  cpu.fz = result == 0; cpu.fn = false; cpu.fh = false

proc cb_rr(cpu: GbCpu; val: uint8): uint8 =
  let old_c = cpu.fc
  cpu.fc = (val and 1) != 0
  result = (val shr 1) or (if old_c: 0x80'u8 else: 0'u8)
  cpu.fz = result == 0; cpu.fn = false; cpu.fh = false

proc cb_sla(cpu: GbCpu; val: uint8): uint8 =
  cpu.fc = (val shr 7) != 0
  result = val shl 1
  cpu.fz = result == 0; cpu.fn = false; cpu.fh = false

proc cb_sra(cpu: GbCpu; val: uint8): uint8 =
  cpu.fc = (val and 1) != 0
  result = (val shr 1) or (val and 0x80)
  cpu.fz = result == 0; cpu.fn = false; cpu.fh = false

proc cb_swap(cpu: GbCpu; val: uint8): uint8 =
  result = ((val and 0xF) shl 4) or (val shr 4)
  cpu.fz = result == 0; cpu.fc = false; cpu.fn = false; cpu.fh = false

proc cb_srl(cpu: GbCpu; val: uint8): uint8 =
  cpu.fc = (val and 1) != 0
  result = val shr 1
  cpu.fz = result == 0; cpu.fn = false; cpu.fh = false

# ---------------------------------------------------------------------------
# CB-prefixed dispatch table
# ---------------------------------------------------------------------------
# Cycle counts:
#   Register ops (non-(HL)): 8  (4 CB fetch + 4 sub-opcode fetch)
#   (HL) read-only (BIT):   12  (4 + 4 + 4 HL-read)
#   (HL) read+write ops:    16  (4 + 4 + 4 HL-read + 4 HL-write)
#
# Each closure calls cpu_inc_pc(cpu) to advance past the CB sub-opcode byte.

var CB_PREFIXED* = [
  # 0x00 RLC B
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.b = cb_rlc(cpu, cpu.b); 8,
  # 0x01 RLC C
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.c = cb_rlc(cpu, cpu.c); 8,
  # 0x02 RLC D
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.d = cb_rlc(cpu, cpu.d); 8,
  # 0x03 RLC E
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.e = cb_rlc(cpu, cpu.e); 8,
  # 0x04 RLC H
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.h = cb_rlc(cpu, cpu.h); 8,
  # 0x05 RLC L
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.l = cb_rlc(cpu, cpu.l); 8,
  # 0x06 RLC (HL)
  proc(cpu: GbCpu; gb: GB): int =
    cpu_inc_pc(cpu)
    `cpu_memory_at_hl=`(cpu, gb, cb_rlc(cpu, cpu_memory_at_hl(cpu, gb)))
    16,
  # 0x07 RLC A
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.a = cb_rlc(cpu, cpu.a); 8,

  # 0x08 RRC B
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.b = cb_rrc(cpu, cpu.b); 8,
  # 0x09 RRC C
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.c = cb_rrc(cpu, cpu.c); 8,
  # 0x0A RRC D
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.d = cb_rrc(cpu, cpu.d); 8,
  # 0x0B RRC E
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.e = cb_rrc(cpu, cpu.e); 8,
  # 0x0C RRC H
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.h = cb_rrc(cpu, cpu.h); 8,
  # 0x0D RRC L
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.l = cb_rrc(cpu, cpu.l); 8,
  # 0x0E RRC (HL)
  proc(cpu: GbCpu; gb: GB): int =
    cpu_inc_pc(cpu)
    `cpu_memory_at_hl=`(cpu, gb, cb_rrc(cpu, cpu_memory_at_hl(cpu, gb)))
    16,
  # 0x0F RRC A
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.a = cb_rrc(cpu, cpu.a); 8,

  # 0x10 RL B
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.b = cb_rl(cpu, cpu.b); 8,
  # 0x11 RL C
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.c = cb_rl(cpu, cpu.c); 8,
  # 0x12 RL D
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.d = cb_rl(cpu, cpu.d); 8,
  # 0x13 RL E
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.e = cb_rl(cpu, cpu.e); 8,
  # 0x14 RL H
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.h = cb_rl(cpu, cpu.h); 8,
  # 0x15 RL L
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.l = cb_rl(cpu, cpu.l); 8,
  # 0x16 RL (HL)
  proc(cpu: GbCpu; gb: GB): int =
    cpu_inc_pc(cpu)
    `cpu_memory_at_hl=`(cpu, gb, cb_rl(cpu, cpu_memory_at_hl(cpu, gb)))
    16,
  # 0x17 RL A
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.a = cb_rl(cpu, cpu.a); 8,

  # 0x18 RR B
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.b = cb_rr(cpu, cpu.b); 8,
  # 0x19 RR C
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.c = cb_rr(cpu, cpu.c); 8,
  # 0x1A RR D
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.d = cb_rr(cpu, cpu.d); 8,
  # 0x1B RR E
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.e = cb_rr(cpu, cpu.e); 8,
  # 0x1C RR H
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.h = cb_rr(cpu, cpu.h); 8,
  # 0x1D RR L
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.l = cb_rr(cpu, cpu.l); 8,
  # 0x1E RR (HL)
  proc(cpu: GbCpu; gb: GB): int =
    cpu_inc_pc(cpu)
    `cpu_memory_at_hl=`(cpu, gb, cb_rr(cpu, cpu_memory_at_hl(cpu, gb)))
    16,
  # 0x1F RR A
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.a = cb_rr(cpu, cpu.a); 8,

  # 0x20 SLA B
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.b = cb_sla(cpu, cpu.b); 8,
  # 0x21 SLA C
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.c = cb_sla(cpu, cpu.c); 8,
  # 0x22 SLA D
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.d = cb_sla(cpu, cpu.d); 8,
  # 0x23 SLA E
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.e = cb_sla(cpu, cpu.e); 8,
  # 0x24 SLA H
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.h = cb_sla(cpu, cpu.h); 8,
  # 0x25 SLA L
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.l = cb_sla(cpu, cpu.l); 8,
  # 0x26 SLA (HL)
  proc(cpu: GbCpu; gb: GB): int =
    cpu_inc_pc(cpu)
    `cpu_memory_at_hl=`(cpu, gb, cb_sla(cpu, cpu_memory_at_hl(cpu, gb)))
    16,
  # 0x27 SLA A
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.a = cb_sla(cpu, cpu.a); 8,

  # 0x28 SRA B
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.b = cb_sra(cpu, cpu.b); 8,
  # 0x29 SRA C
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.c = cb_sra(cpu, cpu.c); 8,
  # 0x2A SRA D
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.d = cb_sra(cpu, cpu.d); 8,
  # 0x2B SRA E
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.e = cb_sra(cpu, cpu.e); 8,
  # 0x2C SRA H
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.h = cb_sra(cpu, cpu.h); 8,
  # 0x2D SRA L
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.l = cb_sra(cpu, cpu.l); 8,
  # 0x2E SRA (HL)
  proc(cpu: GbCpu; gb: GB): int =
    cpu_inc_pc(cpu)
    `cpu_memory_at_hl=`(cpu, gb, cb_sra(cpu, cpu_memory_at_hl(cpu, gb)))
    16,
  # 0x2F SRA A
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.a = cb_sra(cpu, cpu.a); 8,

  # 0x30 SWAP B
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.b = cb_swap(cpu, cpu.b); 8,
  # 0x31 SWAP C
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.c = cb_swap(cpu, cpu.c); 8,
  # 0x32 SWAP D
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.d = cb_swap(cpu, cpu.d); 8,
  # 0x33 SWAP E
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.e = cb_swap(cpu, cpu.e); 8,
  # 0x34 SWAP H
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.h = cb_swap(cpu, cpu.h); 8,
  # 0x35 SWAP L
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.l = cb_swap(cpu, cpu.l); 8,
  # 0x36 SWAP (HL)
  proc(cpu: GbCpu; gb: GB): int =
    cpu_inc_pc(cpu)
    `cpu_memory_at_hl=`(cpu, gb, cb_swap(cpu, cpu_memory_at_hl(cpu, gb)))
    16,
  # 0x37 SWAP A
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.a = cb_swap(cpu, cpu.a); 8,

  # 0x38 SRL B
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.b = cb_srl(cpu, cpu.b); 8,
  # 0x39 SRL C
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.c = cb_srl(cpu, cpu.c); 8,
  # 0x3A SRL D
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.d = cb_srl(cpu, cpu.d); 8,
  # 0x3B SRL E
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.e = cb_srl(cpu, cpu.e); 8,
  # 0x3C SRL H
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.h = cb_srl(cpu, cpu.h); 8,
  # 0x3D SRL L
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.l = cb_srl(cpu, cpu.l); 8,
  # 0x3E SRL (HL)
  proc(cpu: GbCpu; gb: GB): int =
    cpu_inc_pc(cpu)
    `cpu_memory_at_hl=`(cpu, gb, cb_srl(cpu, cpu_memory_at_hl(cpu, gb)))
    16,
  # 0x3F SRL A
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.a = cb_srl(cpu, cpu.a); 8,

  # 0x40 BIT 0,B
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.fz = (cpu.b and 0x01) == 0; cpu.fn = false; cpu.fh = true; 8,
  # 0x41 BIT 0,C
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.fz = (cpu.c and 0x01) == 0; cpu.fn = false; cpu.fh = true; 8,
  # 0x42 BIT 0,D
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.fz = (cpu.d and 0x01) == 0; cpu.fn = false; cpu.fh = true; 8,
  # 0x43 BIT 0,E
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.fz = (cpu.e and 0x01) == 0; cpu.fn = false; cpu.fh = true; 8,
  # 0x44 BIT 0,H
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.fz = (cpu.h and 0x01) == 0; cpu.fn = false; cpu.fh = true; 8,
  # 0x45 BIT 0,L
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.fz = (cpu.l and 0x01) == 0; cpu.fn = false; cpu.fh = true; 8,
  # 0x46 BIT 0,(HL)
  proc(cpu: GbCpu; gb: GB): int =
    cpu_inc_pc(cpu)
    cpu.fz = (cpu_memory_at_hl(cpu, gb) and 0x01) == 0; cpu.fn = false; cpu.fh = true
    12,
  # 0x47 BIT 0,A
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.fz = (cpu.a and 0x01) == 0; cpu.fn = false; cpu.fh = true; 8,

  # 0x48 BIT 1,B
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.fz = (cpu.b and 0x02) == 0; cpu.fn = false; cpu.fh = true; 8,
  # 0x49 BIT 1,C
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.fz = (cpu.c and 0x02) == 0; cpu.fn = false; cpu.fh = true; 8,
  # 0x4A BIT 1,D
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.fz = (cpu.d and 0x02) == 0; cpu.fn = false; cpu.fh = true; 8,
  # 0x4B BIT 1,E
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.fz = (cpu.e and 0x02) == 0; cpu.fn = false; cpu.fh = true; 8,
  # 0x4C BIT 1,H
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.fz = (cpu.h and 0x02) == 0; cpu.fn = false; cpu.fh = true; 8,
  # 0x4D BIT 1,L
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.fz = (cpu.l and 0x02) == 0; cpu.fn = false; cpu.fh = true; 8,
  # 0x4E BIT 1,(HL)
  proc(cpu: GbCpu; gb: GB): int =
    cpu_inc_pc(cpu)
    cpu.fz = (cpu_memory_at_hl(cpu, gb) and 0x02) == 0; cpu.fn = false; cpu.fh = true
    12,
  # 0x4F BIT 1,A
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.fz = (cpu.a and 0x02) == 0; cpu.fn = false; cpu.fh = true; 8,

  # 0x50 BIT 2,B
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.fz = (cpu.b and 0x04) == 0; cpu.fn = false; cpu.fh = true; 8,
  # 0x51 BIT 2,C
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.fz = (cpu.c and 0x04) == 0; cpu.fn = false; cpu.fh = true; 8,
  # 0x52 BIT 2,D
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.fz = (cpu.d and 0x04) == 0; cpu.fn = false; cpu.fh = true; 8,
  # 0x53 BIT 2,E
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.fz = (cpu.e and 0x04) == 0; cpu.fn = false; cpu.fh = true; 8,
  # 0x54 BIT 2,H
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.fz = (cpu.h and 0x04) == 0; cpu.fn = false; cpu.fh = true; 8,
  # 0x55 BIT 2,L
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.fz = (cpu.l and 0x04) == 0; cpu.fn = false; cpu.fh = true; 8,
  # 0x56 BIT 2,(HL)
  proc(cpu: GbCpu; gb: GB): int =
    cpu_inc_pc(cpu)
    cpu.fz = (cpu_memory_at_hl(cpu, gb) and 0x04) == 0; cpu.fn = false; cpu.fh = true
    12,
  # 0x57 BIT 2,A
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.fz = (cpu.a and 0x04) == 0; cpu.fn = false; cpu.fh = true; 8,

  # 0x58 BIT 3,B
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.fz = (cpu.b and 0x08) == 0; cpu.fn = false; cpu.fh = true; 8,
  # 0x59 BIT 3,C
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.fz = (cpu.c and 0x08) == 0; cpu.fn = false; cpu.fh = true; 8,
  # 0x5A BIT 3,D
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.fz = (cpu.d and 0x08) == 0; cpu.fn = false; cpu.fh = true; 8,
  # 0x5B BIT 3,E
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.fz = (cpu.e and 0x08) == 0; cpu.fn = false; cpu.fh = true; 8,
  # 0x5C BIT 3,H
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.fz = (cpu.h and 0x08) == 0; cpu.fn = false; cpu.fh = true; 8,
  # 0x5D BIT 3,L
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.fz = (cpu.l and 0x08) == 0; cpu.fn = false; cpu.fh = true; 8,
  # 0x5E BIT 3,(HL)
  proc(cpu: GbCpu; gb: GB): int =
    cpu_inc_pc(cpu)
    cpu.fz = (cpu_memory_at_hl(cpu, gb) and 0x08) == 0; cpu.fn = false; cpu.fh = true
    12,
  # 0x5F BIT 3,A
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.fz = (cpu.a and 0x08) == 0; cpu.fn = false; cpu.fh = true; 8,

  # 0x60 BIT 4,B
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.fz = (cpu.b and 0x10) == 0; cpu.fn = false; cpu.fh = true; 8,
  # 0x61 BIT 4,C
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.fz = (cpu.c and 0x10) == 0; cpu.fn = false; cpu.fh = true; 8,
  # 0x62 BIT 4,D
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.fz = (cpu.d and 0x10) == 0; cpu.fn = false; cpu.fh = true; 8,
  # 0x63 BIT 4,E
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.fz = (cpu.e and 0x10) == 0; cpu.fn = false; cpu.fh = true; 8,
  # 0x64 BIT 4,H
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.fz = (cpu.h and 0x10) == 0; cpu.fn = false; cpu.fh = true; 8,
  # 0x65 BIT 4,L
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.fz = (cpu.l and 0x10) == 0; cpu.fn = false; cpu.fh = true; 8,
  # 0x66 BIT 4,(HL)
  proc(cpu: GbCpu; gb: GB): int =
    cpu_inc_pc(cpu)
    cpu.fz = (cpu_memory_at_hl(cpu, gb) and 0x10) == 0; cpu.fn = false; cpu.fh = true
    12,
  # 0x67 BIT 4,A
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.fz = (cpu.a and 0x10) == 0; cpu.fn = false; cpu.fh = true; 8,

  # 0x68 BIT 5,B
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.fz = (cpu.b and 0x20) == 0; cpu.fn = false; cpu.fh = true; 8,
  # 0x69 BIT 5,C
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.fz = (cpu.c and 0x20) == 0; cpu.fn = false; cpu.fh = true; 8,
  # 0x6A BIT 5,D
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.fz = (cpu.d and 0x20) == 0; cpu.fn = false; cpu.fh = true; 8,
  # 0x6B BIT 5,E
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.fz = (cpu.e and 0x20) == 0; cpu.fn = false; cpu.fh = true; 8,
  # 0x6C BIT 5,H
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.fz = (cpu.h and 0x20) == 0; cpu.fn = false; cpu.fh = true; 8,
  # 0x6D BIT 5,L
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.fz = (cpu.l and 0x20) == 0; cpu.fn = false; cpu.fh = true; 8,
  # 0x6E BIT 5,(HL)
  proc(cpu: GbCpu; gb: GB): int =
    cpu_inc_pc(cpu)
    cpu.fz = (cpu_memory_at_hl(cpu, gb) and 0x20) == 0; cpu.fn = false; cpu.fh = true
    12,
  # 0x6F BIT 5,A
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.fz = (cpu.a and 0x20) == 0; cpu.fn = false; cpu.fh = true; 8,

  # 0x70 BIT 6,B
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.fz = (cpu.b and 0x40) == 0; cpu.fn = false; cpu.fh = true; 8,
  # 0x71 BIT 6,C
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.fz = (cpu.c and 0x40) == 0; cpu.fn = false; cpu.fh = true; 8,
  # 0x72 BIT 6,D
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.fz = (cpu.d and 0x40) == 0; cpu.fn = false; cpu.fh = true; 8,
  # 0x73 BIT 6,E
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.fz = (cpu.e and 0x40) == 0; cpu.fn = false; cpu.fh = true; 8,
  # 0x74 BIT 6,H
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.fz = (cpu.h and 0x40) == 0; cpu.fn = false; cpu.fh = true; 8,
  # 0x75 BIT 6,L
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.fz = (cpu.l and 0x40) == 0; cpu.fn = false; cpu.fh = true; 8,
  # 0x76 BIT 6,(HL)
  proc(cpu: GbCpu; gb: GB): int =
    cpu_inc_pc(cpu)
    cpu.fz = (cpu_memory_at_hl(cpu, gb) and 0x40) == 0; cpu.fn = false; cpu.fh = true
    12,
  # 0x77 BIT 6,A
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.fz = (cpu.a and 0x40) == 0; cpu.fn = false; cpu.fh = true; 8,

  # 0x78 BIT 7,B
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.fz = (cpu.b and 0x80) == 0; cpu.fn = false; cpu.fh = true; 8,
  # 0x79 BIT 7,C
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.fz = (cpu.c and 0x80) == 0; cpu.fn = false; cpu.fh = true; 8,
  # 0x7A BIT 7,D
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.fz = (cpu.d and 0x80) == 0; cpu.fn = false; cpu.fh = true; 8,
  # 0x7B BIT 7,E
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.fz = (cpu.e and 0x80) == 0; cpu.fn = false; cpu.fh = true; 8,
  # 0x7C BIT 7,H
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.fz = (cpu.h and 0x80) == 0; cpu.fn = false; cpu.fh = true; 8,
  # 0x7D BIT 7,L
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.fz = (cpu.l and 0x80) == 0; cpu.fn = false; cpu.fh = true; 8,
  # 0x7E BIT 7,(HL)
  proc(cpu: GbCpu; gb: GB): int =
    cpu_inc_pc(cpu)
    cpu.fz = (cpu_memory_at_hl(cpu, gb) and 0x80) == 0; cpu.fn = false; cpu.fh = true
    12,
  # 0x7F BIT 7,A
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.fz = (cpu.a and 0x80) == 0; cpu.fn = false; cpu.fh = true; 8,

  # 0x80 RES 0,B
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.b = cpu.b and not 0x01'u8; 8,
  # 0x81 RES 0,C
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.c = cpu.c and not 0x01'u8; 8,
  # 0x82 RES 0,D
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.d = cpu.d and not 0x01'u8; 8,
  # 0x83 RES 0,E
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.e = cpu.e and not 0x01'u8; 8,
  # 0x84 RES 0,H
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.h = cpu.h and not 0x01'u8; 8,
  # 0x85 RES 0,L
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.l = cpu.l and not 0x01'u8; 8,
  # 0x86 RES 0,(HL)
  proc(cpu: GbCpu; gb: GB): int =
    cpu_inc_pc(cpu)
    `cpu_memory_at_hl=`(cpu, gb, cpu_memory_at_hl(cpu, gb) and not 0x01'u8)
    16,
  # 0x87 RES 0,A
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.a = cpu.a and not 0x01'u8; 8,

  # 0x88 RES 1,B
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.b = cpu.b and not 0x02'u8; 8,
  # 0x89 RES 1,C
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.c = cpu.c and not 0x02'u8; 8,
  # 0x8A RES 1,D
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.d = cpu.d and not 0x02'u8; 8,
  # 0x8B RES 1,E
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.e = cpu.e and not 0x02'u8; 8,
  # 0x8C RES 1,H
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.h = cpu.h and not 0x02'u8; 8,
  # 0x8D RES 1,L
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.l = cpu.l and not 0x02'u8; 8,
  # 0x8E RES 1,(HL)
  proc(cpu: GbCpu; gb: GB): int =
    cpu_inc_pc(cpu)
    `cpu_memory_at_hl=`(cpu, gb, cpu_memory_at_hl(cpu, gb) and not 0x02'u8)
    16,
  # 0x8F RES 1,A
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.a = cpu.a and not 0x02'u8; 8,

  # 0x90 RES 2,B
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.b = cpu.b and not 0x04'u8; 8,
  # 0x91 RES 2,C
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.c = cpu.c and not 0x04'u8; 8,
  # 0x92 RES 2,D
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.d = cpu.d and not 0x04'u8; 8,
  # 0x93 RES 2,E
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.e = cpu.e and not 0x04'u8; 8,
  # 0x94 RES 2,H
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.h = cpu.h and not 0x04'u8; 8,
  # 0x95 RES 2,L
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.l = cpu.l and not 0x04'u8; 8,
  # 0x96 RES 2,(HL)
  proc(cpu: GbCpu; gb: GB): int =
    cpu_inc_pc(cpu)
    `cpu_memory_at_hl=`(cpu, gb, cpu_memory_at_hl(cpu, gb) and not 0x04'u8)
    16,
  # 0x97 RES 2,A
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.a = cpu.a and not 0x04'u8; 8,

  # 0x98 RES 3,B
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.b = cpu.b and not 0x08'u8; 8,
  # 0x99 RES 3,C
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.c = cpu.c and not 0x08'u8; 8,
  # 0x9A RES 3,D
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.d = cpu.d and not 0x08'u8; 8,
  # 0x9B RES 3,E
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.e = cpu.e and not 0x08'u8; 8,
  # 0x9C RES 3,H
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.h = cpu.h and not 0x08'u8; 8,
  # 0x9D RES 3,L
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.l = cpu.l and not 0x08'u8; 8,
  # 0x9E RES 3,(HL)
  proc(cpu: GbCpu; gb: GB): int =
    cpu_inc_pc(cpu)
    `cpu_memory_at_hl=`(cpu, gb, cpu_memory_at_hl(cpu, gb) and not 0x08'u8)
    16,
  # 0x9F RES 3,A
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.a = cpu.a and not 0x08'u8; 8,

  # 0xA0 RES 4,B
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.b = cpu.b and not 0x10'u8; 8,
  # 0xA1 RES 4,C
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.c = cpu.c and not 0x10'u8; 8,
  # 0xA2 RES 4,D
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.d = cpu.d and not 0x10'u8; 8,
  # 0xA3 RES 4,E
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.e = cpu.e and not 0x10'u8; 8,
  # 0xA4 RES 4,H
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.h = cpu.h and not 0x10'u8; 8,
  # 0xA5 RES 4,L
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.l = cpu.l and not 0x10'u8; 8,
  # 0xA6 RES 4,(HL)
  proc(cpu: GbCpu; gb: GB): int =
    cpu_inc_pc(cpu)
    `cpu_memory_at_hl=`(cpu, gb, cpu_memory_at_hl(cpu, gb) and not 0x10'u8)
    16,
  # 0xA7 RES 4,A
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.a = cpu.a and not 0x10'u8; 8,

  # 0xA8 RES 5,B
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.b = cpu.b and not 0x20'u8; 8,
  # 0xA9 RES 5,C
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.c = cpu.c and not 0x20'u8; 8,
  # 0xAA RES 5,D
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.d = cpu.d and not 0x20'u8; 8,
  # 0xAB RES 5,E
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.e = cpu.e and not 0x20'u8; 8,
  # 0xAC RES 5,H
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.h = cpu.h and not 0x20'u8; 8,
  # 0xAD RES 5,L
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.l = cpu.l and not 0x20'u8; 8,
  # 0xAE RES 5,(HL)
  proc(cpu: GbCpu; gb: GB): int =
    cpu_inc_pc(cpu)
    `cpu_memory_at_hl=`(cpu, gb, cpu_memory_at_hl(cpu, gb) and not 0x20'u8)
    16,
  # 0xAF RES 5,A
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.a = cpu.a and not 0x20'u8; 8,

  # 0xB0 RES 6,B
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.b = cpu.b and not 0x40'u8; 8,
  # 0xB1 RES 6,C
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.c = cpu.c and not 0x40'u8; 8,
  # 0xB2 RES 6,D
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.d = cpu.d and not 0x40'u8; 8,
  # 0xB3 RES 6,E
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.e = cpu.e and not 0x40'u8; 8,
  # 0xB4 RES 6,H
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.h = cpu.h and not 0x40'u8; 8,
  # 0xB5 RES 6,L
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.l = cpu.l and not 0x40'u8; 8,
  # 0xB6 RES 6,(HL)
  proc(cpu: GbCpu; gb: GB): int =
    cpu_inc_pc(cpu)
    `cpu_memory_at_hl=`(cpu, gb, cpu_memory_at_hl(cpu, gb) and not 0x40'u8)
    16,
  # 0xB7 RES 6,A
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.a = cpu.a and not 0x40'u8; 8,

  # 0xB8 RES 7,B
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.b = cpu.b and not 0x80'u8; 8,
  # 0xB9 RES 7,C
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.c = cpu.c and not 0x80'u8; 8,
  # 0xBA RES 7,D
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.d = cpu.d and not 0x80'u8; 8,
  # 0xBB RES 7,E
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.e = cpu.e and not 0x80'u8; 8,
  # 0xBC RES 7,H
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.h = cpu.h and not 0x80'u8; 8,
  # 0xBD RES 7,L
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.l = cpu.l and not 0x80'u8; 8,
  # 0xBE RES 7,(HL)
  proc(cpu: GbCpu; gb: GB): int =
    cpu_inc_pc(cpu)
    `cpu_memory_at_hl=`(cpu, gb, cpu_memory_at_hl(cpu, gb) and not 0x80'u8)
    16,
  # 0xBF RES 7,A
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.a = cpu.a and not 0x80'u8; 8,

  # 0xC0 SET 0,B
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.b = cpu.b or 0x01'u8; 8,
  # 0xC1 SET 0,C
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.c = cpu.c or 0x01'u8; 8,
  # 0xC2 SET 0,D
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.d = cpu.d or 0x01'u8; 8,
  # 0xC3 SET 0,E
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.e = cpu.e or 0x01'u8; 8,
  # 0xC4 SET 0,H
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.h = cpu.h or 0x01'u8; 8,
  # 0xC5 SET 0,L
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.l = cpu.l or 0x01'u8; 8,
  # 0xC6 SET 0,(HL)
  proc(cpu: GbCpu; gb: GB): int =
    cpu_inc_pc(cpu)
    `cpu_memory_at_hl=`(cpu, gb, cpu_memory_at_hl(cpu, gb) or 0x01'u8)
    16,
  # 0xC7 SET 0,A
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.a = cpu.a or 0x01'u8; 8,

  # 0xC8 SET 1,B
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.b = cpu.b or 0x02'u8; 8,
  # 0xC9 SET 1,C
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.c = cpu.c or 0x02'u8; 8,
  # 0xCA SET 1,D
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.d = cpu.d or 0x02'u8; 8,
  # 0xCB SET 1,E
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.e = cpu.e or 0x02'u8; 8,
  # 0xCC SET 1,H
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.h = cpu.h or 0x02'u8; 8,
  # 0xCD SET 1,L
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.l = cpu.l or 0x02'u8; 8,
  # 0xCE SET 1,(HL)
  proc(cpu: GbCpu; gb: GB): int =
    cpu_inc_pc(cpu)
    `cpu_memory_at_hl=`(cpu, gb, cpu_memory_at_hl(cpu, gb) or 0x02'u8)
    16,
  # 0xCF SET 1,A
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.a = cpu.a or 0x02'u8; 8,

  # 0xD0 SET 2,B
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.b = cpu.b or 0x04'u8; 8,
  # 0xD1 SET 2,C
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.c = cpu.c or 0x04'u8; 8,
  # 0xD2 SET 2,D
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.d = cpu.d or 0x04'u8; 8,
  # 0xD3 SET 2,E
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.e = cpu.e or 0x04'u8; 8,
  # 0xD4 SET 2,H
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.h = cpu.h or 0x04'u8; 8,
  # 0xD5 SET 2,L
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.l = cpu.l or 0x04'u8; 8,
  # 0xD6 SET 2,(HL)
  proc(cpu: GbCpu; gb: GB): int =
    cpu_inc_pc(cpu)
    `cpu_memory_at_hl=`(cpu, gb, cpu_memory_at_hl(cpu, gb) or 0x04'u8)
    16,
  # 0xD7 SET 2,A
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.a = cpu.a or 0x04'u8; 8,

  # 0xD8 SET 3,B
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.b = cpu.b or 0x08'u8; 8,
  # 0xD9 SET 3,C
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.c = cpu.c or 0x08'u8; 8,
  # 0xDA SET 3,D
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.d = cpu.d or 0x08'u8; 8,
  # 0xDB SET 3,E
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.e = cpu.e or 0x08'u8; 8,
  # 0xDC SET 3,H
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.h = cpu.h or 0x08'u8; 8,
  # 0xDD SET 3,L
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.l = cpu.l or 0x08'u8; 8,
  # 0xDE SET 3,(HL)
  proc(cpu: GbCpu; gb: GB): int =
    cpu_inc_pc(cpu)
    `cpu_memory_at_hl=`(cpu, gb, cpu_memory_at_hl(cpu, gb) or 0x08'u8)
    16,
  # 0xDF SET 3,A
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.a = cpu.a or 0x08'u8; 8,

  # 0xE0 SET 4,B
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.b = cpu.b or 0x10'u8; 8,
  # 0xE1 SET 4,C
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.c = cpu.c or 0x10'u8; 8,
  # 0xE2 SET 4,D
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.d = cpu.d or 0x10'u8; 8,
  # 0xE3 SET 4,E
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.e = cpu.e or 0x10'u8; 8,
  # 0xE4 SET 4,H
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.h = cpu.h or 0x10'u8; 8,
  # 0xE5 SET 4,L
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.l = cpu.l or 0x10'u8; 8,
  # 0xE6 SET 4,(HL)
  proc(cpu: GbCpu; gb: GB): int =
    cpu_inc_pc(cpu)
    `cpu_memory_at_hl=`(cpu, gb, cpu_memory_at_hl(cpu, gb) or 0x10'u8)
    16,
  # 0xE7 SET 4,A
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.a = cpu.a or 0x10'u8; 8,

  # 0xE8 SET 5,B
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.b = cpu.b or 0x20'u8; 8,
  # 0xE9 SET 5,C
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.c = cpu.c or 0x20'u8; 8,
  # 0xEA SET 5,D
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.d = cpu.d or 0x20'u8; 8,
  # 0xEB SET 5,E
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.e = cpu.e or 0x20'u8; 8,
  # 0xEC SET 5,H
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.h = cpu.h or 0x20'u8; 8,
  # 0xED SET 5,L
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.l = cpu.l or 0x20'u8; 8,
  # 0xEE SET 5,(HL)
  proc(cpu: GbCpu; gb: GB): int =
    cpu_inc_pc(cpu)
    `cpu_memory_at_hl=`(cpu, gb, cpu_memory_at_hl(cpu, gb) or 0x20'u8)
    16,
  # 0xEF SET 5,A
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.a = cpu.a or 0x20'u8; 8,

  # 0xF0 SET 6,B
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.b = cpu.b or 0x40'u8; 8,
  # 0xF1 SET 6,C
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.c = cpu.c or 0x40'u8; 8,
  # 0xF2 SET 6,D
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.d = cpu.d or 0x40'u8; 8,
  # 0xF3 SET 6,E
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.e = cpu.e or 0x40'u8; 8,
  # 0xF4 SET 6,H
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.h = cpu.h or 0x40'u8; 8,
  # 0xF5 SET 6,L
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.l = cpu.l or 0x40'u8; 8,
  # 0xF6 SET 6,(HL)
  proc(cpu: GbCpu; gb: GB): int =
    cpu_inc_pc(cpu)
    `cpu_memory_at_hl=`(cpu, gb, cpu_memory_at_hl(cpu, gb) or 0x40'u8)
    16,
  # 0xF7 SET 6,A
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.a = cpu.a or 0x40'u8; 8,

  # 0xF8 SET 7,B
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.b = cpu.b or 0x80'u8; 8,
  # 0xF9 SET 7,C
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.c = cpu.c or 0x80'u8; 8,
  # 0xFA SET 7,D
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.d = cpu.d or 0x80'u8; 8,
  # 0xFB SET 7,E
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.e = cpu.e or 0x80'u8; 8,
  # 0xFC SET 7,H
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.h = cpu.h or 0x80'u8; 8,
  # 0xFD SET 7,L
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.l = cpu.l or 0x80'u8; 8,
  # 0xFE SET 7,(HL)
  proc(cpu: GbCpu; gb: GB): int =
    cpu_inc_pc(cpu)
    `cpu_memory_at_hl=`(cpu, gb, cpu_memory_at_hl(cpu, gb) or 0x80'u8)
    16,
  # 0xFF SET 7,A
  proc(cpu: GbCpu; gb: GB): int = cpu_inc_pc(cpu); cpu.a = cpu.a or 0x80'u8; 8,
]
