let context_id = -1;

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

// Base Rowstag
const baseRowBase = {
  "KeyQ": "b", "KeyW": "l", "KeyE": "d", "KeyR": "c", "KeyT": "v",
  "KeyY": "j", "KeyU": "f", "KeyI": "o", "KeyO": "u", "KeyA": "n", 
  "KeyS": "r", "KeyD": "t", "KeyF": "s", "KeyG": "g", "KeyH": "y", 
  "KeyJ": "h", "KeyK": "a", "KeyL": "e", "Semicolon": "i", "KeyN": "k", 
  "KeyM": "p", "KeyP": ",", "Comma": "'", "Period": ";", "Slash": ".",
  "KeyZ": "x", "KeyX": "q", "KeyC": "m", "KeyV": "w", "KeyB": "z"
};
const baseRowShift = {
  "KeyQ": "B", "KeyW": "L", "KeyE": "D", "KeyR": "C", "KeyT": "V",
  "KeyY": "J", "KeyU": "F", "KeyI": "O", "KeyO": "U", "KeyA": "N", 
  "KeyS": "R", "KeyD": "T", "KeyF": "S", "KeyG": "G", "KeyH": "Y", 
  "KeyJ": "H", "KeyK": "A", "KeyL": "E", "Semicolon": "I", "KeyN": "K", 
  "KeyM": "P", "KeyP": "<", "Comma": "\"", "Period": ":", "Slash": ">",
  "KeyZ": "X", "KeyX": "Q", "KeyC": "M", "KeyV": "W", "KeyB": "Z"
};

// Angle Mod
const angleRowBase = { ...baseRowBase, "KeyZ": "q", "KeyX": "m", "KeyC": "w", "KeyV": "z", "KeyB": "x" };
const angleRowShift = { ...baseRowShift, "KeyZ": "Q", "KeyX": "M", "KeyC": "W", "KeyV": "Z", "KeyB": "X" };

// Punct Mod (Removes re-mappings for Comma/Period/Slash so physical QWERTY keys pass through)
const punctRowBase = { ...baseRowBase, "KeyP": ";" };
delete punctRowBase["Comma"];
delete punctRowBase["Period"];
delete punctRowBase["Slash"];

const punctRowShift = { ...baseRowShift, "KeyP": ":" };
delete punctRowShift["Comma"];
delete punctRowShift["Period"];
delete punctRowShift["Slash"];

// Angle + Punct Mod
const anglePunctRowBase = { ...angleRowBase, "KeyP": ";" };
delete anglePunctRowBase["Comma"];
delete anglePunctRowBase["Period"];
delete anglePunctRowBase["Slash"];

const anglePunctRowShift = { ...angleRowShift, "KeyP": ":" };
delete anglePunctRowShift["Comma"];
delete anglePunctRowShift["Period"];
delete anglePunctRowShift["Slash"];

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

  if (consumeExpectedEvent(keyData.code, keyData.type)) {
    return false;
  }

  let isShifted = keyData.shiftKey;
  if (keyData.capsLock && keyData.code.startsWith("Key")) {
     isShifted = !isShifted;
  }

  let mapBase, mapShift;
  if (engineID === "gallium_v2_qwerty_punct_rowstag") {
    mapBase = anglePunctRowBase; mapShift = anglePunctRowShift;
  } else if (engineID === "gallium_v2_punct") {
    mapBase = punctRowBase; mapShift = punctRowShift;
  } else if (engineID === "gallium_v2_rowstag") {
    mapBase = angleRowBase; mapShift = angleRowShift;
  } else {
    mapBase = baseRowBase; mapShift = baseRowShift;
  }
  
  let targetMap = isShifted ? mapShift : mapBase;
  let mappedChar = targetMap[keyData.code];

  if (mappedChar) {
    let targetCode = getTargetCode(mapBase[keyData.code]);
    addExpectedEvent(targetCode, keyData.type);

    chrome.input.ime.sendKeyEvents({
      "contextID": context_id,
      "keyData": [{
        "type": keyData.type,
        "key": mappedChar,
        "code": targetCode,
        "shiftKey": keyData.shiftKey,
        "capsLock": keyData.capsLock,
        "ctrlKey": keyData.ctrlKey,
        "altKey": keyData.altKey
      }]
    });
    return true;
  }

  return false; 
});
