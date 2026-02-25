# Package
version = "0.1.0"
author  = "Matthew Beck"
description = "A GBA/GBC emulator"
license = "MIT"

srcDir = "src"
bin    = @["crab"]

# Dependencies
requires "nim >= 2.0.0"
requires "sdl2 >= 2.0.4"

# Pass linker flags to find SDL2 on Homebrew (macOS arm64)
