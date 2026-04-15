let context_id = -1;

// Track injected events to prevent infinite loops when we send a fake key event
// that comes back to us from ChromeOS.
let expectedEvents = {};

function addExpectedEvent(code, type) {
  let key = code + ":" + type;
  expectedEvents[key] = (expectedEvents[key] || 0) + 1;
}

function consumeExpectedEvent(code, type) {
  let key = code + ":" + type;
  if (expectedEvents[key] > 0) {
    expectedEvents[key]--;
    return true;
  }
  return false;
}

// Rowstag (Standard) Mappings
const rowstagBase = {
  "KeyQ": "b",
  "KeyW": "l",
  "KeyE": "d",
  "KeyR": "c",
  "KeyT": "v",
  "KeyY": "j",
  "KeyU": "f",
  "KeyI": "o",
  "KeyO": "u",
  "KeyA": "n",
  "KeyS": "r",
  "KeyD": "t",
  "KeyF": "s",
  "KeyG": "g",
  "KeyH": "y",
  "KeyJ": "h",
  "KeyK": "a",
  "KeyL": "e",
  "Semicolon": "i",
  "KeyN": "k",
  "KeyM": "p",
  "KeyP": ";",
  "KeyZ": "q",
  "KeyX": "m",
  "KeyC": "w",
  "KeyV": "z",
  "KeyB": "x"
};
const rowstagShift = {
  "KeyQ": "B",
  "KeyW": "L",
  "KeyE": "D",
  "KeyR": "C",
  "KeyT": "V",
  "KeyY": "J",
  "KeyU": "F",
  "KeyI": "O",
  "KeyO": "U",
  "KeyA": "N",
  "KeyS": "R",
  "KeyD": "T",
  "KeyF": "S",
  "KeyG": "G",
  "KeyH": "Y",
  "KeyJ": "H",
  "KeyK": "A",
  "KeyL": "E",
  "Semicolon": "I",
  "KeyN": "K",
  "KeyM": "P",
  "KeyP": ":",
  "KeyZ": "Q",
  "KeyX": "M",
  "KeyC": "W",
  "KeyV": "Z",
  "KeyB": "X"
};


// Helper function to get the physical KeyCode for the mapped character
function getTargetCode(char) {
  let c = char.toLowerCase();
  if (/[a-z]/.test(c)) return "Key" + c.toUpperCase();
  const punct = { ",": "Comma", ".": "Period", ";": "Semicolon", "'": "Quote", "/": "Slash" };
  return punct[c] || "";
}

chrome.input.ime.onFocus.addListener(function(context) {
  context_id = context.contextID;
});

chrome.input.ime.onKeyEvent.addListener(function(engineID, keyData) {
  if (context_id === -1) return false;
  

  // If this is a fake event we just generated, let it pass through to the system!
  if (consumeExpectedEvent(keyData.code, keyData.type)) {
    return false;
  }

  let isShifted = keyData.shiftKey;
  if (keyData.capsLock && keyData.code.startsWith("Key")) {
     isShifted = !isShifted;
  }

  let mapBase = rowstagBase;
  let mapShift = rowstagShift;
  
  let targetMap = isShifted ? mapShift : mapBase;
  let mappedChar = targetMap[keyData.code];

  if (mappedChar) {
    // Generate a FAKE keyboard event with the new letter instead of using commitText.
    // Crostini completely ignores commitText, but it respects fake keydown events!
    let targetCode = getTargetCode(mapBase[keyData.code]);
    
    // Mark this event as an expected injection to prevent infinite looping
    addExpectedEvent(targetCode, keyData.type);

    chrome.input.ime.sendKeyEvents({
      "contextID": context_id,
      "keyData": [{
        "type": keyData.type, // 'keydown' or 'keyup'
        "key": mappedChar,
        "code": targetCode,
        "shiftKey": keyData.shiftKey,
        "capsLock": keyData.capsLock,
        "ctrlKey": keyData.ctrlKey,
        "altKey": keyData.altKey
      }]
    });
    return true; // We handled it, swallow the physical QWERTY key
  }

  // Not a mapped key, let system handle (like Space, Enter, Tab, etc.)
  return false; 
});
