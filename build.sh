#!/bin/bash
# Builds Sentra Notch.app (universal) with the Swift command line tools — no Xcode project needed.
#   bash build.sh            → build/Sentra Notch.app
# MediaRemoteAdapter (BSD-3-Clause, github.com/ungive/mediaremote-adapter) is built and bundled when cmake is available.
set -euo pipefail
cd "$(dirname "$0")"
APP="build/Sentra Notch.app"
rm -rf build && mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
FW="-framework AppKit -framework SwiftUI -framework IOKit -framework IOBluetooth -framework CoreAudio -framework AudioToolbox -framework AVFoundation -framework EventKit -framework Carbon -framework ServiceManagement -framework CryptoKit -framework QuickLookThumbnailing -framework Quartz"
for arch in arm64 x86_64; do
  swiftc -O -swift-version 5 -parse-as-library -target "$arch-apple-macos14.0" -module-name SentraNotch \
    Sources/SentraNotch/*.swift $FW -o "build/SentraNotch-$arch"
done
lipo -create build/SentraNotch-arm64 build/SentraNotch-x86_64 -output "$APP/Contents/MacOS/SentraNotch"
cp Resources/Info.plist "$APP/Contents/"
# icon
ICON=build/AppIcon.iconset; mkdir -p "$ICON"
for s in 16 32 128 256 512; do
  sips -z $s $s Resources/AppIcon.png --out "$ICON/icon_${s}x${s}.png" >/dev/null
  sips -z $((s*2)) $((s*2)) Resources/AppIcon.png --out "$ICON/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICON" -o "$APP/Contents/Resources/AppIcon.icns"
cp LICENSE "$APP/Contents/Resources/LICENSE.txt"
# Now playing adapter
if command -v cmake >/dev/null; then
  rm -rf build/mra && git clone -q --depth 1 -b v0.7.7 https://github.com/ungive/mediaremote-adapter.git build/mra
  (cd build/mra && cmake -S . -B out -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64" >/dev/null && cmake --build out --config Release >/dev/null)
  cp -R build/mra/out/MediaRemoteAdapter.framework "$APP/Contents/Resources/"
  cp build/mra/out/MediaRemoteAdapterTestClient "$APP/Contents/Resources/" 2>/dev/null || true
  cp build/mra/bin/mediaremote-adapter.pl "$APP/Contents/Resources/"
  cp build/mra/LICENSE "$APP/Contents/Resources/MediaRemoteAdapter-LICENSE.txt"
fi
codesign --force --deep --sign - "$APP"
echo "Built $APP"
