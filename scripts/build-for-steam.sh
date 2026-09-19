#!/usr/bin/env bash
# Prepare a Godot export directory for Steam upload.
#
# Steam depots expect a directory layout that matches the final install path
# on the user's machine. This script takes the Godot export output (a single
# executable + a .pck data file when embed_pck=false) and packages it into a
# clean directory ready for steamcmd.
#
# Usage:
#   scripts/build-for-steam.sh <platform> <export_dir> <output_dir>
#
#   platform    linux | macos
#   export_dir  directory containing the Godot export output
#   output_dir  where the Steam-ready directory will be created
#
# Example:
#   scripts/build-for-steam.sh linux build/linux build/steam/linux

set -euo pipefail

PLATFORM="${1:?Usage: $0 <linux|macos> <export_dir> <output_dir>}"
EXPORT_DIR="${2:?Usage: $0 <linux|macos> <export_dir> <output_dir>}"
OUTPUT_DIR="${3:?Usage: $0 <linux|macos> <export_dir> <output_dir>}"

mkdir -p "$OUTPUT_DIR"

case "$PLATFORM" in
  linux)
    # Copy the executable and the .pck data file
    shopt -s nullglob
    files=("$EXPORT_DIR"/*)
    shopt -u nullglob

    if [ ${#files[@]} -eq 0 ]; then
      echo "ERROR: No files found in $EXPORT_DIR" >&2
      exit 1
    fi

    for f in "${files[@]}"; do
      cp -v "$f" "$OUTPUT_DIR/"
    done

    # Make the executable actually executable (Godot usually does this, but be safe)
    exe=$(find "$OUTPUT_DIR" -maxdepth 1 -type f ! -name "*.pck" ! -name "*.txt" | head -n 1)
    if [ -n "$exe" ]; then
      chmod +x "$exe"
      echo "Prepared Linux build: $OUTPUT_DIR/"
      ls -la "$OUTPUT_DIR/"
    else
      echo "ERROR: Could not find executable in $EXPORT_DIR" >&2
      exit 1
    fi
    ;;

  macos)
    # macOS exports produce an .app bundle + a .app.pck data file
    app=$(find "$EXPORT_DIR" -maxdepth 1 -name "*.app" -type d | head -n 1)
    if [ -z "$app" ]; then
      echo "ERROR: No .app bundle found in $EXPORT_DIR" >&2
      exit 1
    fi

    # Copy the .app bundle (preserving directory structure)
    cp -a "$app" "$OUTPUT_DIR/"

    # Copy the data file if present
    pck=$(find "$EXPORT_DIR" -maxdepth 1 -name "*.app.pck" | head -n 1)
    if [ -n "$pck" ]; then
      cp -v "$pck" "$OUTPUT_DIR/"
    fi

    echo "Prepared macOS build: $OUTPUT_DIR/"
    ls -la "$OUTPUT_DIR/"
    ;;

  *)
    echo "ERROR: Unknown platform '$PLATFORM'. Use 'linux' or 'macos'." >&2
    exit 1
    ;;
esac

echo "Done."
