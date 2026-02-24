import std/[os, parseopt, strutils]
import crab/gba/gba

const VERSION = "0.1.0"

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
        print_help()
        quit(0)
      of "version":
        echo VERSION
        quit(0)
      of "run-bios":
        run_bios = true
      of "skip-bios":
        run_bios = false
      else:
        echo "Unknown option: --" & p.key & ". Use --help for help."
        quit(1)
    of cmdArgument:
      pos_args.add(p.key)

  case pos_args.len
  of 0:
    echo "No ROM specified. Use --help for usage."
    quit(1)
  of 1:
    rom_path = pos_args[0]
  of 2:
    bios_path = pos_args[0]
    rom_path  = pos_args[1]
  else:
    echo "Too many arguments. Use --help for usage."
    quit(1)

  if rom_path == "":
    echo "No ROM specified."
    quit(1)

  if not fileExists(rom_path):
    echo "ROM file not found: " & rom_path
    quit(1)

  if bios_path != "" and not fileExists(bios_path):
    echo "BIOS file not found: " & bios_path
    quit(1)

  let gba = new_gba(bios_path, rom_path, run_bios)
  gba.post_init()

  while true:
    gba.run_until_frame()

main()
