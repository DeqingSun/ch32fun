#!/usr/bin/env bash
# Collect CH32V003 firmware built by Make and/or PlatformIO into a staging directory.
set -euo pipefail

OUT_DIR="${1:-ch32v003-artifacts}"
MODE="${2:-make}" # make | pio | all
SEARCH_GLOB="${3:-examples*}"

mkdir -p "$OUT_DIR"

collect_make() {
  local count=0
  while IFS= read -r funconfig; do
    local dir makefile name parent dest
    dir=$(dirname "$funconfig")
    makefile="$dir/Makefile"

    if [[ ! -f "$makefile" ]]; then
      continue
    fi

    if ! grep -qE '^\s*TARGET_MCU\?*=CH32V003\s*($|#)' "$makefile"; then
      continue
    fi

    name=$(basename "$dir")
    parent=$(basename "$(dirname "$dir")")

    if [[ ! -f "$dir/$name.elf" ]]; then
      echo "Skipping $dir (no $name.elf)"
      continue
    fi

    dest="$OUT_DIR/make/$parent/$name"
    mkdir -p "$dest"

    echo "Collecting Make build: $dir"
    (cd "$dir" && make -s "$name.bin")
    cp "$dir/$name.elf" "$dir/$name.bin" "$dest/"
    if [[ -f "$dir/$name.hex" ]]; then
      cp "$dir/$name.hex" "$dest/"
    fi
    count=$((count + 1))
  done < <(find $SEARCH_GLOB -maxdepth 3 -name funconfig.h 2>/dev/null | sort)

  echo "Collected $count CH32V003 Make binaries"
}

collect_pio() {
  local count=0 env fw_dir dest
  while IFS= read -r env; do
    fw_dir=".pio/build/$env"
    if [[ ! -f "$fw_dir/firmware.elf" ]]; then
      echo "Skipping PIO env $env (no firmware.elf)"
      continue
    fi

    dest="$OUT_DIR/pio/$env"
    mkdir -p "$dest"
    echo "Collecting PIO build: $env"
    cp "$fw_dir/firmware.elf" "$dest/"
    if [[ -f "$fw_dir/firmware.bin" ]]; then
      cp "$fw_dir/firmware.bin" "$dest/"
    fi
    count=$((count + 1))
  done < <(awk '/^\[env:/{gsub(/\]/,""); env=substr($0,6)} /extends = fun_base_003/{print env}' platformio.ini)

  echo "Collected $count CH32V003 PlatformIO binaries"
}

case "$MODE" in
  make) collect_make ;;
  pio)  collect_pio ;;
  all)  collect_make; collect_pio ;;
  *)    echo "Unknown mode: $MODE (use make, pio, or all)" >&2; exit 1 ;;
esac

if [[ -z "$(find "$OUT_DIR" -type f 2>/dev/null)" ]]; then
  echo "No CH32V003 binaries found in $OUT_DIR" >&2
  exit 1
fi
