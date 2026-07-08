# Chibi

Native macOS desk pet (Swift + AppKit). Idle / poke / drag / roam + menu-bar Quit.

Built as the desktop companion for [personalLLM-api](https://github.com/Taal0/personalLLM-api); chat/LLM wiring comes later.

## Run

```bash
open ChibiNative.xcodeproj
# or
xcodebuild -project ChibiNative.xcodeproj -scheme ChibiNative -configuration Debug -derivedDataPath build build
open build/Build/Products/Debug/ChibiNative.app
```

Quit from the menu-bar status item.

## Layout

Flipped overlay web coords, ImageIO APNG player, hitTest click-through, roam/theme math in Swift.
