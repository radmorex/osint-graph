#!/bin/zsh
# Lightweight native macOS build (~300 KB, Swift + WKWebView, no Electron).
# Output: dist-native/OSINT Graph.app   Requires: Xcode Command Line Tools (xcode-select --install)
set -euo pipefail
HERE="${0:A:h}"
ROOT="${HERE:h}"
OUT="$ROOT/dist-native"
APP="$OUT/OSINT Graph.app"
TMP="${TMPDIR:-/tmp}/osint-graph-native-build"
rm -rf "$APP" "$TMP"; mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$TMP"

swiftc -O -swift-version 5 -module-cache-path "$TMP/mc" -framework Cocoa -framework WebKit \
  "$HERE/main.swift" -o "$APP/Contents/MacOS/OSINTGraph"

cp "$ROOT/src/index.html" "$APP/Contents/Resources/index.html"

swiftc -swift-version 5 -module-cache-path "$TMP/mc" -framework Cocoa "$HERE/icon.swift" -o "$TMP/icon"
"$TMP/icon" "$TMP/AppIcon.iconset"
if ! iconutil -c icns "$TMP/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns" 2>/dev/null; then
  python3 -I - "$TMP/AppIcon.iconset" "$APP/Contents/Resources/AppIcon.icns" <<'PY'
import sys, struct, os
d, out = sys.argv[1], sys.argv[2]
m = [('icp4','icon_16x16.png'),('icp5','icon_32x32.png'),('ic07','icon_128x128.png'),('ic08','icon_256x256.png'),
     ('ic09','icon_512x512.png'),('ic10','icon_512x512@2x.png'),('ic11','icon_16x16@2x.png'),('ic12','icon_32x32@2x.png'),
     ('ic13','icon_128x128@2x.png'),('ic14','icon_256x256@2x.png')]
body = b''.join(t.encode() + struct.pack('>I', len(p) + 8) + p for t, p in ((t, open(os.path.join(d, f), 'rb').read()) for t, f in m))
open(out, 'wb').write(b'icns' + struct.pack('>I', len(body) + 8) + body)
PY
fi

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>OSINT Graph</string>
  <key>CFBundleDisplayName</key><string>OSINT Graph</string>
  <key>CFBundleIdentifier</key><string>io.github.radmorex.osintgraph.native</string>
  <key>CFBundleExecutable</key><string>OSINTGraph</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>12.0</string>
  <key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST

codesign --force --deep --sign - "$APP"
echo "Done: $APP"
