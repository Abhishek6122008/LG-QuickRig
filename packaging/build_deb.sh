#!/usr/bin/env bash
# Builds an installable .deb of the Linux desktop app. Run from the repo root
# on Ubuntu/Debian (CI does this on ubuntu-latest — see .github/workflows/ci.yml).
#
# Plain dpkg-deb on a staged tree: no fpm, no flutter_distributor, nothing to
# keep up to date. The Depends list below is hand-written, and CI installs the
# result to prove it resolves.
set -euo pipefail

PKG=lg-quickrig
ARCH=amd64
BINARY=lg_quickrig                       # linux/CMakeLists.txt BINARY_NAME
VERSION=$(sed -n 's/^version: *\([0-9.]*\).*/\1/p' pubspec.yaml)
BUNDLE=build/linux/x64/release/bundle
STAGE=build/deb/$PKG

flutter build linux --release

rm -rf build/deb
mkdir -p "$STAGE"/DEBIAN \
         "$STAGE/opt/$PKG" \
         "$STAGE/usr/bin" \
         "$STAGE/usr/share/applications" \
         "$STAGE/usr/share/icons/hicolor/192x192/apps"

# The bundle keeps its own lib/ next to the binary (rpath is $ORIGIN/lib), so
# it has to stay together — /opt is the honest home for that.
cp -r "$BUNDLE"/. "$STAGE/opt/$PKG/"
ln -s "/opt/$PKG/$BINARY" "$STAGE/usr/bin/$PKG"
cp "packaging/$PKG.desktop" "$STAGE/usr/share/applications/"
cp assets/tray_icon.png "$STAGE/usr/share/icons/hicolor/192x192/apps/$PKG.png"

cat > "$STAGE/DEBIAN/control" <<EOF
Package: $PKG
Version: $VERSION
Section: utils
Priority: optional
Architecture: $ARCH
Depends: libgtk-3-0, libsecret-1-0, libjsoncpp25, libayatana-appindicator3-1
Maintainer: Abhishek Chaudhary <abhishek.6122008@gmail.com>
Homepage: https://github.com/Abhishek6122008/LG-QuickRig
Description: One-tap control for a Liquid Galaxy rig
 Camera moves, KML overlays, map markers and node management over SSH,
 from the desktop window or the system tray. Credentials are stored in
 the system keyring, never in plaintext.
EOF

OUT="build/deb/${PKG}_${VERSION}_${ARCH}.deb"
dpkg-deb --root-owner-group --build "$STAGE" "$OUT"
echo "built $OUT"
