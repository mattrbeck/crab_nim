# APU implementation (included by gba.nim)

const APU_CHANNELS*       = 2
const APU_BUFFER_SIZE*    = 1024
const APU_SAMPLE_RATE*    = 32768
const CPU_CLOCK_SPEED*    = 1 shl 24
const APU_SAMPLE_PERIOD*  = CPU_CLOCK_SPEED div APU_SAMPLE_RATE
const FRAME_SEQ_RATE*     = 512
const FRAME_SEQ_PERIOD*   = CPU_CLOCK_SPEED div FRAME_SEQ_RATE

proc new_apu*(gba: GBA): APU =
  result = APU(
    gba: gba,
    soundcnt_l: SOUNDCNT_L(value: 0),
    soundcnt_h: SOUNDCNT_H(value: 0),
    sound_enabled: false,
    soundbias: SOUNDBIAS(value: 0x200),
    buffer_pos: 0,
    frame_sequencer_stage: 0,
    first_half_of_length_period: false,
    sync: true,
  )
  result.buffer = newSeq[int16](APU_BUFFER_SIZE)
  result.channel1 = new_channel1(gba)
  result.channel2 = new_channel2(gba)
  result.channel3 = new_channel3(gba)
  result.channel4 = new_channel4(gba)
  result.dma_channels = new_dma_channels(gba)
  # TODO: SDL audio setup
  result.tick_frame_sequencer()
  result.get_sample()

proc toggle_sync*(apu: APU) =
  apu.sync = not apu.sync

proc timer_overflow*(apu: APU; timer: int) =
  apu.dma_channels.timer_overflow(timer)

proc tick_frame_sequencer*(apu: APU) =
  apu.first_half_of_length_period = (apu.frame_sequencer_stage and 1) == 0
  case apu.frame_sequencer_stage
  of 0:
    apu.channel1.length_step(); apu.channel2.length_step()
    apu.channel3.length_step(); apu.channel4.length_step()
  of 1: discard
  of 2:
    apu.channel1.length_step(); apu.channel2.length_step()
    apu.channel3.length_step(); apu.channel4.length_step()
    apu.channel1.sweep_step()
  of 3: discard
  of 4:
    apu.channel1.length_step(); apu.channel2.length_step()
    apu.channel3.length_step(); apu.channel4.length_step()
  of 5: discard
  of 6:
    apu.channel1.length_step(); apu.channel2.length_step()
    apu.channel3.length_step(); apu.channel4.length_step()
    apu.channel1.sweep_step()
  of 7:
    apu.channel1.volume_step()
    apu.channel2.volume_step()
    apu.channel4.volume_step()
  else: discard
  apu.frame_sequencer_stage += 1
  if apu.frame_sequencer_stage > 7: apu.frame_sequencer_stage = 0
  let g = apu.gba
  g.scheduler.schedule(FRAME_SEQ_PERIOD, proc() {.closure.} = apu.tick_frame_sequencer(), etAPU)

proc get_sample*(apu: APU) =
  if apu.soundcnt_h.sound_volume >= 3:
    raise newException(Exception, "Prohibited sound 1-4 volume " & $apu.soundcnt_h.sound_volume)
  let psg_sound =
    apu.channel1.ch1_get_amplitude() * int16(apu.soundcnt_l.channel_1_left) +
    apu.channel2.ch2_get_amplitude() * int16(apu.soundcnt_l.channel_2_left) +
    apu.channel3.ch3_get_amplitude() * int16(apu.soundcnt_l.channel_3_left) +
    apu.channel4.ch4_get_amplitude() * int16(apu.soundcnt_l.channel_4_left)
  let shift = 5 - int(apu.soundcnt_h.sound_volume)
  let psg_left  = int32(psg_sound) * int32(apu.soundcnt_l.left_volume) shr shift
  let psg_right = int32(psg_sound) * int32(apu.soundcnt_l.right_volume) shr shift
  let (dma_a, dma_b) = apu.dma_channels.dma_channels_get_amplitude()
  let dma_a_scaled = int32(dma_a) shl apu.soundcnt_h.dma_sound_a_volume
  let dma_b_scaled = int32(dma_b) shl apu.soundcnt_h.dma_sound_b_volume
  let dma_left  = dma_a_scaled * int32(apu.soundcnt_h.dma_sound_a_left)  + dma_b_scaled * int32(apu.soundcnt_h.dma_sound_b_left)
  let dma_right = dma_a_scaled * int32(apu.soundcnt_h.dma_sound_a_right) + dma_b_scaled * int32(apu.soundcnt_h.dma_sound_b_right)
  let bias = int32(apu.soundbias.bias_level)
  let total_left  = int16(max(0, min(0x3FF, psg_left  + dma_left  + bias)) - bias)
  let total_right = int16(max(0, min(0x3FF, psg_right + dma_right + bias)) - bias)
  apu.buffer[apu.buffer_pos]     = total_left  * 32
  apu.buffer[apu.buffer_pos + 1] = total_right * 32
  apu.buffer_pos += 2
  if apu.buffer_pos >= APU_BUFFER_SIZE:
    # TODO: SDL audio queue
    apu.buffer_pos = 0
  let g = apu.gba
  g.scheduler.schedule(APU_SAMPLE_PERIOD, proc() {.closure.} = apu.get_sample(), etAPU)

proc `[]`*(apu: APU; io_addr: uint32): uint8 =
  if ch1_in_range(io_addr):      apu.channel1.ch1_read(io_addr)
  elif ch2_in_range(io_addr):    apu.channel2.ch2_read(io_addr)
  elif ch3_in_range(io_addr):    apu.channel3.ch3_read(io_addr)
  elif ch4_in_range(io_addr):    apu.channel4.ch4_read(io_addr)
  elif dma_channels_in_range(io_addr): apu.dma_channels.dma_channels_read(io_addr)
  else:
    case io_addr
    of 0x80: uint8(apu.soundcnt_l.value)
    of 0x81: uint8(apu.soundcnt_l.value shr 8)
    of 0x82: uint8(apu.soundcnt_h.value)
    of 0x83: uint8(apu.soundcnt_h.value shr 8)
    of 0x84:
      (if apu.sound_enabled: 0x80'u8 else: 0'u8) or
      (if apu.channel4.enabled: 0b1000'u8 else: 0'u8) or
      (if apu.channel3.enabled: 0b0100'u8 else: 0'u8) or
      (if apu.channel2.enabled: 0b0010'u8 else: 0'u8) or
      (if apu.channel1.enabled: 0b0001'u8 else: 0'u8)
    of 0x85, 0x86, 0x87: 0'u8
    of 0x88: uint8(apu.soundbias.value)
    of 0x89: uint8(apu.soundbias.value shr 8)
    of 0x8A, 0x8B: 0'u8
    else: apu.gba.bus.read_open_bus_value(io_addr)

proc `[]=`*(apu: APU; io_addr: uint32; value: uint8) =
  if not (apu.sound_enabled or
          (io_addr >= 0x82 and io_addr <= 0x89) or
          (io_addr >= WAVE_RAM_LOW and io_addr <= WAVE_RAM_HIGH)):
    return
  if ch1_in_range(io_addr):      apu.channel1.ch1_write(io_addr, value)
  elif ch2_in_range(io_addr):    apu.channel2.ch2_write(io_addr, value)
  elif ch3_in_range(io_addr):    apu.channel3.ch3_write(io_addr, value)
  elif ch4_in_range(io_addr):    apu.channel4.ch4_write(io_addr, value)
  elif dma_channels_in_range(io_addr): apu.dma_channels.dma_channels_write(io_addr, value)
  else:
    case io_addr
    of 0x80: apu.soundcnt_l.value = (apu.soundcnt_l.value and 0xFF00'u16) or uint16(value)
    of 0x81: apu.soundcnt_l.value = (apu.soundcnt_l.value and 0x00FF'u16) or (uint16(value) shl 8)
    of 0x82: apu.soundcnt_h.value = (apu.soundcnt_h.value and 0xFF00'u16) or uint16(value)
    of 0x83: apu.soundcnt_h.value = (apu.soundcnt_h.value and 0x00FF'u16) or (uint16(value) shl 8)
    of 0x84:
      if (value and 0x80) == 0 and apu.sound_enabled:
        for addr in 0x60'u32..0x81'u32:
          apu[addr] = 0x00'u8
        apu.sound_enabled = false
      elif (value and 0x80) > 0 and not apu.sound_enabled:
        apu.sound_enabled = true
        apu.frame_sequencer_stage = 0
        apu.channel1.length_counter = 0
        apu.channel2.length_counter = 0
        apu.channel3.length_counter = 0
        apu.channel4.length_counter = 0
    of 0x85: discard
    of 0x88: apu.soundbias.value = (apu.soundbias.value and 0xFF00'u16) or uint16(value)
    of 0x89: apu.soundbias.value = (apu.soundbias.value and 0x00FF'u16) or (uint16(value) shl 8)
    of 0xA8..0xAF: discard
    else: discard
