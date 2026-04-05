# FIFO PPU — Unimplemented Edge Cases & Hardware Quirks

Reference: [pandocs pixel_fifo.md](https://github.com/corybsa/pandocs/blob/develop/content/pixel_fifo.md)

## 1. VRAM Access Blocking

When VRAM access is blocked, reads should return `$FF` instead of the actual VRAM contents. The fetcher's Get Tile, Get Tile Data Low, and Get Tile Data High steps should all check for blocked access.

**VRAM access is blocked when:**
- LCD is turning off
- At scanline 0 on CGB when not in double speed mode
- When switching from mode 3 to mode 0
- On CGB when searching OAM and index 37 is reached

**VRAM access is restored when:**
- At scanline 0 on DMG and CGB in double speed mode
- On DMG when searching OAM and index 37 is reached
- After switching from mode 2 to mode 3

These conditions are only checked when entering STOP mode. Access is always restored upon leaving STOP mode.

**Files:** `fifo_ppu.nim` (tick_bg_fetcher, sprite_fetch_merge)

## 2. CGB Palette Access Blocking

When CGB palette access is blocked, a black pixel should be pushed to the LCD instead of the normal palette-resolved color.

**Palette access is blocked when:**
- LCD is turning off
- First HBlank of the frame
- When searching OAM and index 37 is reached
- After switching from mode 2 to mode 3
- When entering HBlank (mode 0) and not in double speed mode — blocked 2 cycles later regardless

**Palette access is restored when:**
- At the end of mode 2 (OAM search)
- For only 2 cycles when entering HBlank (mode 0) and in double speed mode

Same STOP mode behavior as VRAM access.

**Files:** `fifo_ppu.nim` (tick_shifter pixel rendering)

## 3. Sprite Fetch Abortion

If LCDC.1 (sprite enable) is disabled while the PPU is actively fetching a sprite from OAM, the fetch should be aborted. The spec says:

- Abortion lengthens mode 3 by the number of cycles the previous CPU instruction took plus the residual PPU cycles
- When aborted: render a pixel, advance the BG fetcher one step
- The fetcher advancement adds +1 cycle if the current pixel is not pixel 160
- If the current pixel is 160, stop processing sprites entirely

This requires tracking whether LCDC.1 changes mid-scanline during an active sprite fetch, which involves monitoring writes to the LCDC register during mode 3.

**Files:** `fifo_ppu.nim` (tick_sprite_fetcher), `ppu.nim` (ppu_write LCDC handler)

## 4. Mid-Scanline WX Change Bug

When the window has already started rendering and the value of WX is changed mid-scanline such that the new WX value is reached again, a pixel with color value 0 and the lowest priority should be pushed onto the background FIFO.

This requires detecting WX writes during mode 3 when `fetching_window` is already true, and comparing the new WX against the current pixel position.

**Files:** `fifo_ppu.nim` (tick_shifter window trigger), `ppu.nim` (ppu_write WX handler)

## 5. CGB Ignores LCDC.1 for Sprite Fetch Triggering

On CGB, the LCDC.1 (sprite enable) condition should be ignored when deciding whether to trigger a sprite fetch. Sprites are still fetched (consuming the same cycles / lengthening mode 3), but they render as transparent. The current implementation checks `sprite_enabled(ppu)` (LCDC.1) before triggering a fetch, which means on CGB, disabling sprites via LCDC.1 would incorrectly skip the fetch entirely, affecting mode 3 timing.

The fix: on CGB, always trigger sprite fetches regardless of LCDC.1. Only use LCDC.1 to decide whether to mix the sprite pixel during rendering (in `sprite_wins`).

**Files:** `fifo_ppu.nim` (tick_shifter sprite trigger check)
