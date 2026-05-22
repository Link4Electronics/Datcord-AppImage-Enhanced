#!/bin/sh

set -eu

ARCH=$(uname -m)
VERSION=$(pacman -Q datcord-bin | awk '{print $2; exit}') # example command to get version of application here
export ARCH VERSION
export OUTPATH=./dist
export ADD_HOOKS="self-updater.hook"
export UPINFO="gh-releases-zsync|${GITHUB_REPOSITORY%/*}|${GITHUB_REPOSITORY#*/}|latest|*$ARCH.AppImage.zsync"
export ICON=/usr/share/icons/hicolor/256x256/apps/datcord.png
export DESKTOP=/usr/share/applications/datcord.desktop
export STARTUPWMCLASS=datcord
export DEPLOY_OPENGL=1
export DEPLOY_VULKAN=1
export APPDIR="${APPDIR:-$PWD/AppDir}"

# Deploy dependencies
quick-sharun /usr/bin/datcord /usr/lib/datcord

# Additional changes can be done in between here
# Fix Neutron/Datcord launch-app infinite relaunch loop:
# launch-app (tray/singleton manager) looks for <its_dir>/datcord as the
# Gecko browser binary.  quick-sharun makes that a symlink to launch-app
# itself, so it keeps re-launching itself in an infinite loop.

# 1) Point shared/bin/datcord at the real Gecko binary (not launch-app)
rm -f "$APPDIR"/shared/bin/datcord
ln -s datcord-bin "$APPDIR"/shared/bin/datcord

# 2) Firefox/Gecko loads its runtime resources (omni.ja, libxul.so, etc.)
#    relative to the binary's directory.  Symlink every file from the
#    sharun-managed lib directory into shared/bin/ so Firefox can find
#    them when launched via launch-app.  Skip files that already exist
#    in shared/bin/ as real files (helpers like crashreporter, etc.).
for _f in "$APPDIR"/shared/lib/datcord/*; do
    [ -e "$_f" ] || continue
    _bname=$(basename "$_f")
    if [ ! -e "$APPDIR/shared/bin/$_bname" ] || [ -L "$APPDIR/shared/bin/$_bname" ]; then
        ln -sf ../lib/datcord/"$_bname" "$APPDIR/shared/bin/$_bname"
    fi
done

# 3) Change AppRun's MAIN_BIN from "datcord" to "launch-app" so the
#    entry point goes through the tray/singleton manager.
sed -i 's/^MAIN_BIN=datcord/MAIN_BIN=launch-app/' "$APPDIR"/AppRun

# Turn AppDir into AppImage
quick-sharun --make-appimage

# Test the app for 12 seconds, if the test fails due to the app
# having issues running in the CI use --simple-test instead
quick-sharun --test ./dist/*.AppImage
