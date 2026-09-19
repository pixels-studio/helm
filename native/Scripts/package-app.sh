#!/bin/sh
set -eu

configuration="${1:-debug}"
swift build -c "$configuration"
binary_path="$(swift build -c "$configuration" --show-bin-path)"
app_path=".build/Helm.app"

mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources"
cp "$binary_path/Helm" "$app_path/Contents/MacOS/Helm"
cp "Resources/Info.plist" "$app_path/Contents/Info.plist"
rm -rf "$app_path/Contents/Resources/Icons"
cp -R "Sources/HelmNative/Resources/Icons" "$app_path/Contents/Resources/Icons"
rm -rf "$app_path/SwiftTerm_SwiftTerm.bundle"
codesign --force --sign - "$app_path"
echo "$app_path"
