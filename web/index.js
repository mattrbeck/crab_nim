const showLogButton = document.getElementById("show-log");
const logDiv = document.getElementById("log");
logDiv.hidden = true;
showLogButton.addEventListener("click", () => {
  logDiv.hidden = !logDiv.hidden;
  logDiv.scroll({ top: logDiv.scrollHeight });
});
const log = (message) => {
  let shouldScroll =
    logDiv.scrollTop === logDiv.scrollHeight - logDiv.offsetHeight;
  logDiv.innerHTML += `<p>${message}</p>`;
  if (shouldScroll) logDiv.scroll({ top: logDiv.scrollHeight });
};

const readToEmscriptenFileSystem = (filename, filter = "") => {
  return new Promise((resolve, reject) => {
    let input = document.createElement("input");
    input.type = "file";
    input.accept = filter;
    input.addEventListener("input", () => {
      if (input.files?.length > 0) {
        let reader = new FileReader();
        reader.addEventListener("load", () => {
          let bytes = new Uint8Array(reader.result);
          let stream = FS.open(filename, "w+");
          FS.write(stream, bytes, 0, bytes.length, 0);
          FS.close(stream);
          resolve(filename);
        });
        reader.readAsArrayBuffer(input.files[0]);
      }
    });
    input.click();
  });
};

document
  .getElementById("open-bios")
  .addEventListener("click", () => readToEmscriptenFileSystem("bios.bin"));

document.getElementById("open-rom").addEventListener("click", () => {
  let input = document.createElement("input");
  input.type = "file";
  input.accept = ".gba,.gb,.gbc";
  input.addEventListener("input", () => {
    if (input.files?.length > 0) {
      let file = input.files[0];
      let ext = file.name.substring(file.name.lastIndexOf(".")).toLowerCase();
      let romName = "rom" + ext;
      let reader = new FileReader();
      reader.addEventListener("load", () => {
        let bytes = new Uint8Array(reader.result);
        let stream = FS.open(romName, "w+");
        FS.write(stream, bytes, 0, bytes.length, 0);
        FS.close(stream);
        Module.ccall("initFromEmscripten", null, ["string"], [romName]);
      });
      reader.readAsArrayBuffer(file);
    }
  });
  input.click();
});

var Module = {
  canvas: (() => document.getElementById("canvas"))(),
  onRuntimeInitialized: () => {
    const tick = () => {
      Module._loop_tick();
      requestAnimationFrame(tick);
    };
    requestAnimationFrame(tick);
  },
};

const pressKey = (keycode, down = true) => {
  let event = new Event(down ? "keydown" : "keyup", {
    bubbles: true,
    cancelable: "true",
  });
  event.keyCode = keycode;
  event.which = keycode;
  document.dispatchEvent(event);
};

const pressAllKeys = (keycodes, down) => {
  for (let keycode of keycodes) {
    pressKey(keycode, down);
  }
};

var currentDpadTouchId = null;
var currentDpadElement = null;

const getTouch = (touchList, touchId) => {
  for (let touch of touchList) {
    if (touch.identifier == touchId) {
      return touch;
    }
  }
};

const getKeycodes = (element) =>
  element?.getAttribute("keycodes")?.split(" ") ?? [];

const dpadTouchStart = (event) => {
  let element = event.target;
  if (currentDpadTouchId == null) {
    currentDpadTouchId = event.targetTouches[0].identifier;
    if (element.hasAttribute("keycodes")) {
      currentDpadElement = element;
      pressAllKeys(getKeycodes(element), true);
    }
  }
};

const dpadTouchMove = (event) => {
  if (currentDpadTouchId == null) return;
  let touch = getTouch(event.targetTouches, currentDpadTouchId);
  if (touch != null) {
    let element = document.elementFromPoint(touch.clientX, touch.clientY);
    if (element == currentDpadElement) return;
    if (element == null) return;
    let oldKeycodes = getKeycodes(currentDpadElement);
    if (element.hasAttribute("keycodes")) {
      let newKeycodes = getKeycodes(element);
      for (let oldKeycode of oldKeycodes) {
        if (newKeycodes.includes(oldKeycode)) continue;
        pressKey(oldKeycode, false);
      }
      for (let newKeycode of newKeycodes) {
        if (oldKeycodes.includes(newKeycode)) continue;
        pressKey(newKeycode, true);
      }
      currentDpadElement = element;
    } else {
      pressAllKeys(oldKeycodes, false);
      currentDpadElement = null;
    }
  }
};

const dpadTouchEnd = (event) => {
  let touch = getTouch(event.changedTouches, currentDpadTouchId);
  if (touch != null) {
    pressAllKeys(getKeycodes(currentDpadElement), false);
    currentDpadTouchId = null;
    currentDpadElement = null;
  }
};

document.getElementById("dpad").addEventListener("touchstart", dpadTouchStart);
document.getElementById("dpad").addEventListener("touchmove", dpadTouchMove);
document.getElementById("dpad").addEventListener("touchend", dpadTouchEnd);
document.getElementById("dpad").addEventListener("touchcancel", dpadTouchEnd);

document.querySelectorAll("[keycode]").forEach((element) =>
  element.addEventListener("touchstart", (event) => {
    pressKey(element.getAttribute("keycode"), true);
  })
);

document.querySelectorAll("[keycode]").forEach((element) =>
  element.addEventListener("touchend", (event) => {
    pressKey(element.getAttribute("keycode"), false);
  })
);
