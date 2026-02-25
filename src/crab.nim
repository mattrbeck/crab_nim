import std/[os, parseopt]
import sdl2
import crab/common/input
import crab/gba/gba

const VERSION = "0.1.0"
const SCALE = 3
const GBA_W = 240
const GBA_H = 160

proc print_help() =
  echo "crab - A GBA emulator"
  echo ""
  echo "Usage: crab [options] [BIOS] [ROM]"
  echo ""
  echo "Options:"
  echo "  -h, --help       Show this help message"
  echo "  --run-bios       Run the BIOS on startup"
  echo "  --skip-bios      Skip the BIOS on startup (default)"
  echo "  --version        Print version"

proc bgr555_to_argb(color: uint16): uint32 =
  let r = uint32(color and 0x1F'u16) shl 3
  let g = uint32((color shr 5) and 0x1F'u16) shl 3
  let b = uint32((color shr 10) and 0x1F'u16) shl 3
  (0xFF'u32 shl 24) or (r shl 16) or (g shl 8) or b

proc keycode_to_input(key: cint): Input =
  if   key == K_x:       Input.A
  elif key == K_z:       Input.B
  elif key == K_a:       Input.L
  elif key == K_s:       Input.R
  elif key == K_RETURN:  Input.START
  elif key == K_SPACE:   Input.SELECT
  elif key == K_RIGHT:   Input.RIGHT
  elif key == K_LEFT:    Input.LEFT
  elif key == K_UP:      Input.UP
  elif key == K_DOWN:    Input.DOWN
  else: Input.A  # ignored below

proc is_gba_key(key: cint): bool =
  key in [K_x, K_z, K_a, K_s, K_RETURN, K_SPACE,
          K_RIGHT, K_LEFT, K_UP, K_DOWN]

proc main() =
  var bios_path = ""
  var rom_path  = ""
  var run_bios  = false
  var pos_args: seq[string] = @[]

  var p = initOptParser(commandLineParams())
  while true:
    p.next()
    case p.kind
    of cmdEnd: break
    of cmdShortOption, cmdLongOption:
      case p.key
      of "h", "help":
        print_help(); quit(0)
      of "version":
        echo VERSION; quit(0)
      of "run-bios":  run_bios = true
      of "skip-bios": run_bios = false
      else:
        echo "Unknown option: --" & p.key; quit(1)
    of cmdArgument:
      pos_args.add(p.key)

  case pos_args.len
  of 0: echo "No ROM specified. Use --help for usage."; quit(1)
  of 1: rom_path = pos_args[0]
  of 2: bios_path = pos_args[0]; rom_path = pos_args[1]
  else: echo "Too many arguments."; quit(1)

  if not fileExists(rom_path):
    echo "ROM file not found: " & rom_path; quit(1)
  if bios_path != "" and not fileExists(bios_path):
    echo "BIOS file not found: " & bios_path; quit(1)

  # Initialize SDL2 first (APU opens audio device during GBA init)
  if sdl2.init(INIT_VIDEO or INIT_AUDIO) != SdlSuccess:
    echo "SDL2 init failed: ", $sdl2.getError(); quit(1)
  defer: sdl2.quit()

  # Initialize GBA
  let gba_emu = new_gba(bios_path, rom_path, run_bios)
  gba_emu.post_init()

  let title = cstring("crab - " & gba_emu.cartridge.title())
  let window = createWindow(
    title,
    SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
    GBA_W * SCALE, GBA_H * SCALE,
    SDL_WINDOW_SHOWN or SDL_WINDOW_RESIZABLE
  )
  if window.isNil:
    echo "Failed to create window: ", $sdl2.getError(); quit(1)
  defer: window.destroy()

  let renderer = createRenderer(window, -1, Renderer_Accelerated or Renderer_PresentVsync)
  if renderer.isNil:
    echo "Failed to create renderer: ", $sdl2.getError(); quit(1)
  defer: renderer.destroy()

  discard renderer.setLogicalSize(GBA_W, GBA_H)

  let texture = renderer.createTexture(
    SDL_PIXELFORMAT_ARGB8888,
    SDL_TEXTUREACCESS_STREAMING,
    GBA_W, GBA_H
  )
  if texture.isNil:
    echo "Failed to create texture: ", $sdl2.getError(); quit(1)
  defer: texture.destroy()

  # Pixel conversion buffer
  var pixels = newSeq[uint32](GBA_W * GBA_H)

  var evt = sdl2.defaultEvent
  var running = true

  while running:
    # Run one GBA frame
    gba_emu.run_until_frame()

    # Convert BGR555 framebuffer to ARGB8888
    for i in 0 ..< GBA_W * GBA_H:
      pixels[i] = bgr555_to_argb(gba_emu.ppu.framebuffer[i])

    # Update texture
    let pitch = cint(GBA_W * sizeof(uint32))
    discard texture.updateTexture(nil, addr pixels[0], pitch)

    # Render
    discard renderer.clear()
    discard renderer.copy(texture, nil, nil)
    renderer.present()

    # Handle events
    while pollEvent(evt):
      case evt.kind
      of QuitEvent:
        running = false
      of KeyDown:
        let key = evt.key.keysym.sym
        if key == K_ESCAPE: running = false
        elif is_gba_key(key):
          gba_emu.handle_input(keycode_to_input(key), true)
      of KeyUp:
        let key = evt.key.keysym.sym
        if is_gba_key(key):
          gba_emu.handle_input(keycode_to_input(key), false)
      else: discard

main()
