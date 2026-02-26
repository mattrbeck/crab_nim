# GB Joypad (included by gb.nim)

proc new_gb_joypad*(): GbJoypad =
  GbJoypad()

proc joypad_read*(j: GbJoypad): uint8 =
  let bits =
    (if j.button_keys:    0x20'u8 else: 0'u8) or
    (if j.direction_keys: 0x10'u8 else: 0'u8) or
    (if (j.down  and j.direction_keys) or (j.start   and j.button_keys): 0x08'u8 else: 0'u8) or
    (if (j.up    and j.direction_keys) or (j.jselect  and j.button_keys): 0x04'u8 else: 0'u8) or
    (if (j.left  and j.direction_keys) or (j.b        and j.button_keys): 0x02'u8 else: 0'u8) or
    (if (j.right and j.direction_keys) or (j.a        and j.button_keys): 0x01'u8 else: 0'u8)
  not bits

proc joypad_write*(j: GbJoypad; val: uint8) =
  j.button_keys    = ((val shr 5) and 0x1) == 0
  j.direction_keys = ((val shr 4) and 0x1) == 0

proc handle_input*(j: GbJoypad; inp: Input; pressed: bool) =
  case inp
  of Input.UP:     j.up     = pressed
  of Input.DOWN:   j.down   = pressed
  of Input.LEFT:   j.left   = pressed
  of Input.RIGHT:  j.right  = pressed
  of Input.A:      j.a      = pressed
  of Input.B:      j.b      = pressed
  of Input.SELECT: j.jselect = pressed
  of Input.START:  j.start  = pressed
  else: discard
