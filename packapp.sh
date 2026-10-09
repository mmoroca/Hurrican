#!/bin/bash
set -e

APP="Hurrican.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

# 1. Copiar binario y datos
cp build/hurrican "$APP/Contents/MacOS/"
cp -r data "$APP/Contents/Resources/"
cp -r lang "$APP/Contents/Resources/"

# 2. Crear carpeta de frameworks y copiar dependencias
FW="$APP/Contents/Frameworks"
mkdir -p "$FW"
cp /opt/homebrew/opt/libepoxy/lib/libepoxy.0.dylib "$FW/"
cp /opt/homebrew/opt/sdl2-compat/lib/libSDL2-2.0.0.dylib "$FW/"
cp /opt/homebrew/opt/sdl2_mixer/lib/libSDL2_mixer-2.0.0.dylib "$FW/"
cp /opt/homebrew/opt/sdl2_image/lib/libSDL2_image-2.0.0.dylib "$FW/"
cp /opt/homebrew/lib/libSDL3.dylib "$FW/"

# 3. Redirigir los install_names del binario a @rpath
BIN="$APP/Contents/MacOS/hurrican"
install_name_tool -change /opt/homebrew/opt/libepoxy/lib/libepoxy.0.dylib \
    @rpath/libepoxy.0.dylib "$BIN"
install_name_tool -change /opt/homebrew/opt/sdl2-compat/lib/libSDL2-2.0.0.dylib \
    @rpath/libSDL2-2.0.0.dylib "$BIN"
install_name_tool -change /opt/homebrew/opt/sdl2_mixer/lib/libSDL2_mixer-2.0.0.dylib \
    @rpath/libSDL2_mixer-2.0.0.dylib "$BIN"
install_name_tool -change /opt/homebrew/opt/sdl2_image/lib/libSDL2_image-2.0.0.dylib \
    @rpath/libSDL2_image-2.0.0.dylib "$BIN"

# 4. Corregir referencias internas
install_name_tool -change /opt/homebrew/opt/sdl2-compat/lib/libSDL2-2.0.0.dylib \
    @loader_path/libSDL2-2.0.0.dylib "$FW/libSDL2_mixer-2.0.0.dylib"
install_name_tool -change /opt/homebrew/opt/sdl2-compat/lib/libSDL2-2.0.0.dylib \
    @loader_path/libSDL2-2.0.0.dylib "$FW/libSDL2_image-2.0.0.dylib"

# 4b. rpath para que sdl2-compat encuentre SDL3
install_name_tool -add_rpath @loader_path "$FW/libSDL2-2.0.0.dylib"

# 5. Añadir rpath para que encuentre las librerías
install_name_tool -add_rpath @executable_path/../Frameworks "$BIN"

# 6. Wrapper launcher
cat > "$APP/Contents/MacOS/launcher" << 'EOF'
#!/bin/bash
BIN_DIR="$(cd "$(dirname "$0")" && pwd)"
RES_DIR="$BIN_DIR/../Resources"

# Si el volumen es de solo lectura (DMG), usar un dir temporal escribible
if [ ! -w "$RES_DIR" ]; then
    WORK_DIR=$(mktemp -d)/Hurrican
    mkdir -p "$WORK_DIR"
    ln -s "$RES_DIR/data" "$WORK_DIR/data"
    ln -s "$RES_DIR/lang" "$WORK_DIR/lang"
    cd "$WORK_DIR"
else
    cd "$RES_DIR"
fi

touch Game_Log.txt 2>/dev/null
exec "$BIN_DIR/hurrican" "$@"
EOF
chmod +x "$APP/Contents/MacOS/launcher"   

# 7. Icono
ICONSET=$(mktemp -d)/icon.iconset
mkdir -p "$ICONSET"
SRC="data/images/hurrican-logo.png"
sips -z 16 16     "$SRC" --out "$ICONSET/icon_16x16.png"      2>/dev/null
sips -z 32 32     "$SRC" --out "$ICONSET/icon_16x16@2x.png"   2>/dev/null
sips -z 32 32     "$SRC" --out "$ICONSET/icon_32x32.png"      2>/dev/null
sips -z 64 64     "$SRC" --out "$ICONSET/icon_32x32@2x.png"   2>/dev/null
sips -z 128 128   "$SRC" --out "$ICONSET/icon_128x128.png"    2>/dev/null
sips -z 256 256   "$SRC" --out "$ICONSET/icon_128x128@2x.png" 2>/dev/null
sips -z 256 256   "$SRC" --out "$ICONSET/icon_256x256.png"    2>/dev/null
sips -z 512 512   "$SRC" --out "$ICONSET/icon_256x256@2x.png" 2>/dev/null
sips -z 512 512   "$SRC" --out "$ICONSET/icon_512x512.png"    2>/dev/null
sips -z 1024 1024 "$SRC" --out "$ICONSET/icon_512x512@2x.png" 2>/dev/null
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/icon.icns"
rm -rf "${ICONSET%/*}"

# 8. Info.plist
cat > "$APP/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>launcher</string>
    <key>CFBundleIdentifier</key>
    <string>io.github.hurricangame.hurrican</string>
    <key>CFBundleName</key>
    <string>Hurrican</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleIconFile</key>
    <string>icon</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

# 9. Firma ad-hoc
codesign --force --deep --sign - "$APP"

# 10. Crear DMG
VOL=$(mktemp -d)
ditto "$APP" "$VOL/Hurrican.app"

cat > "$VOL/README.txt" << 'EOF'
Hurrican for macOS (Apple Silicon)
==================================

This application is distributed "AS IS", without warranty of any kind,
either express or implied. The author shall not be liable for any
damage, data loss, or issue that may occur on your machine.

Usage:
  1. Drag Hurrican.app to your Applications folder
  2. First launch: right-click -> Open -> Open
  3. Enjoy

Original game: https://www.winterworks.de
Fork: https://github.com/HurricanGame/Hurrican
Apple Silicon port: @mmoroca & brave.ai 2026
EOF

hdiutil create -volname "Hurrican" -srcfolder "$VOL" -ov -format UDZO Hurrican.dmg
rm -rf "${VOL:?}"   

echo "✅ Listo: Hurrican.dmg"   