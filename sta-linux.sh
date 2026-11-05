#!/bin/bash
# sta-linux: flash an Android boot.img to the boot partition, then reboot.
# Linux port of n00b69/sta (original: Windows). Made for Xiaomi Pad 5 (nabu).
#
# Usage: sudo sta-linux [options]
#   -p <FILE>  path to the boot image (default: /usr/local/share/sta/boot.img)
#   -a         flash slot A
#   -b         flash slot B (use -a -b to flash both)
#              without -a/-b: partition "boot" if present, otherwise the active slot
#   -f         full flash: write the whole file, skip boot image header parsing
#   -t         write only the size given by the boot image header (like the
#              Windows original). Default writes the whole file, which keeps
#              the AVB footer at the end of the image.
#   -y         flash even if the file is not an Android boot image
#   -n         do not reboot after flashing
#   -s         power off instead of reboot
#   -q         quiet: no summary and no confirmation question
#   -B         do not back up the old partition
#   -d         only show which partition would be flashed, change nothing
#   -h         show this help

set -euo pipefail

DEFAULT_IMG="/usr/local/share/sta/boot.img"
PL="/dev/disk/by-partlabel"

die() { echo "ERROR: $*" >&2; exit 1; }

# u32 FILE OFFSET -> little-endian unsigned 32-bit value (0 if unreadable)
u32() {
  local v
  v=$(od -An -tu4 -j "$2" -N4 "$1" 2>/dev/null | tr -d ' ') || true
  echo "${v:-0}"
}

# bootimg_size FILE -> size in bytes computed from the Android boot image header
# (header versions 0-4). Returns 1 if the file is not a valid boot image.
bootimg_size() {
  local f=$1 ver page k r s total x
  [ "$(head -c 8 "$f" 2>/dev/null)" = "ANDROID!" ] || return 1
  ver=$(u32 "$f" 40)
  pad() { echo $(( ($1 + page - 1) / page * page )); }
  case "$ver" in
    0|1|2)
      page=$(u32 "$f" 36)
      case "$page" in 2048|4096|8192|16384) ;; *) return 1 ;; esac
      k=$(u32 "$f" 8); r=$(u32 "$f" 16); s=$(u32 "$f" 24)
      total=$(( page + $(pad "$k") + $(pad "$r") + $(pad "$s") ))
      if [ "$ver" -ge 1 ]; then x=$(u32 "$f" 1632); total=$(( total + $(pad "$x") )); fi
      if [ "$ver" -ge 2 ]; then x=$(u32 "$f" 1648); total=$(( total + $(pad "$x") )); fi
      ;;
    3|4)
      page=4096
      k=$(u32 "$f" 8); r=$(u32 "$f" 12)
      total=$(( page + $(pad "$k") + $(pad "$r") ))
      if [ "$ver" -ge 4 ]; then x=$(u32 "$f" 1580); total=$(( total + $(pad "$x") )); fi
      ;;
    *) return 1 ;;
  esac
  echo "$total"
}

# gpt_active DISK PARTNUM SECTORSIZE -> success if the A/B "active" bit (bit 50)
# is set in the GPT attributes of that partition.
gpt_active() {
  local disk=$1 pn=$2 ss=$3 lba esz off b
  [ "$(dd if="$disk" bs=1 skip="$ss" count=8 status=none 2>/dev/null | tr -d '\000')" = "EFI PART" ] || return 2
  lba=$(od -An -tu8 -j $((ss + 72)) -N8 "$disk" | tr -d ' ')
  esz=$(od -An -tu4 -j $((ss + 84)) -N4 "$disk" | tr -d ' ')
  [ -n "$lba" ] && [ -n "$esz" ] || return 2
  off=$(( lba * ss + (pn - 1) * esz + 54 ))   # attribute bits 48-55
  b=$(od -An -tu1 -j "$off" -N1 "$disk" | tr -d ' ')
  [ $(( b & 4 )) -ne 0 ]
}

# is_active PARTLABEL -> success if that partition is the active A/B slot
is_active() {
  local dev name pn parent ss
  dev=$(readlink -f "$PL/$1")
  name=${dev##*/}
  [ -r "/sys/class/block/$name/partition" ] || return 2
  pn=$(< "/sys/class/block/$name/partition")
  parent="/dev/$(basename "$(readlink -f "/sys/class/block/$name/..")")"
  ss=$(blockdev --getss "$parent")
  gpt_active "$parent" "$pn" "$ss"
}

main() {
  local IMG="" WANT_A=0 WANT_B=0 FULL=0 TRIM=0 FORCE=0 REBOOT=1 POWEROFF=0
  local QUIET=0 BACKUP=1 DETECT=0 ANS T PART PART_SIZE BK_DIR BK H1 H2
  local IMG_SIZE PARSED WRITE_SIZE
  local TARGETS=()

  while [ $# -gt 0 ]; do
    case "$1" in
      -p) [ $# -ge 2 ] || die "-p needs a file path"; IMG="$2"; shift 2 ;;
      -a) WANT_A=1; shift ;;
      -b) WANT_B=1; shift ;;
      -f) FULL=1; shift ;;
      -t) TRIM=1; shift ;;
      -y) FORCE=1; shift ;;
      -n) REBOOT=0; shift ;;
      -s) POWEROFF=1; shift ;;
      -q) QUIET=1; shift ;;
      -B) BACKUP=0; shift ;;
      -d) DETECT=1; shift ;;
      -h|--help) sed -n '2,22p' "$0"; exit 0 ;;
      -*) die "Invalid option: $1 (use -h for help)" ;;
      *) IMG="$1"; shift ;;
    esac
  done
  IMG="${IMG:-$DEFAULT_IMG}"

  [ "$(id -u)" -eq 0 ] || die "Run as root (sudo)."

  # --- choose target partition(s)
  if [ "$WANT_A" -eq 1 ] || [ "$WANT_B" -eq 1 ]; then
    [ "$WANT_A" -eq 1 ] && TARGETS+=(boot_a)
    [ "$WANT_B" -eq 1 ] && TARGETS+=(boot_b)
  elif [ -b "$PL/boot" ]; then
    TARGETS=(boot)
  elif [ -b "$PL/boot_a" ] && is_active boot_a; then
    TARGETS=(boot_a)
  elif [ -b "$PL/boot_b" ] && is_active boot_b; then
    TARGETS=(boot_b)
  else
    die "No active boot partition found. Use -a or -b to choose one."
  fi

  if [ "$DETECT" -eq 1 ]; then
    echo "Would flash: ${TARGETS[*]}"
    exit 0
  fi

  # --- check the image
  [ -f "$IMG" ] || die "File not found: $IMG"
  IMG_SIZE=$(stat -c %s "$IMG")
  WRITE_SIZE=$IMG_SIZE
  if [ "$FULL" -eq 0 ]; then
    if PARSED=$(bootimg_size "$IMG"); then
      [ "$IMG_SIZE" -ge "$PARSED" ] || die "Boot image is truncated (header says $PARSED bytes, file has $IMG_SIZE)."
      [ "$TRIM" -eq 1 ] && WRITE_SIZE=$PARSED
    elif [ "$FORCE" -eq 1 ]; then
      :  # -y: flash the whole file anyway
    elif [ "$QUIET" -eq 1 ]; then
      die "$IMG is not an Android boot image (use -y to flash it anyway)."
    else
      echo "WARNING: $IMG is not an Android boot image."
      read -r -p "Type 'yes' to flash it anyway: " ANS
      [ "$ANS" = "yes" ] || die "Cancelled."
    fi
  fi

  # --- check the targets
  for T in "${TARGETS[@]}"; do
    PART="$PL/$T"
    [ -b "$PART" ] || die "Partition $PART not found. Check: ls $PL/"
    PART_SIZE=$(blockdev --getsize64 "$PART")
    [ "$WRITE_SIZE" -le "$PART_SIZE" ] || die "Image ($WRITE_SIZE B) is larger than $T ($PART_SIZE B)."
    [ "$QUIET" -eq 1 ] || echo "Flashing $IMG ($WRITE_SIZE bytes) -> $PART"
  done

  if [ "$QUIET" -ne 1 ]; then
    read -r -p "Continue flashing? Type 'yes' to continue: " ANS
    [ "$ANS" = "yes" ] || die "Cancelled."
  fi

  H1=$(head -c "$WRITE_SIZE" "$IMG" | sha256sum | cut -d' ' -f1)

  # --- flash
  for T in "${TARGETS[@]}"; do
    PART="$PL/$T"
    if [ "$BACKUP" -eq 1 ]; then
      BK_DIR="${SUDO_USER:+/home/$SUDO_USER}"; BK_DIR="${BK_DIR:-/root}/sta-backup"
      mkdir -p "$BK_DIR"
      BK="$BK_DIR/${T}-$(date +%Y%m%d-%H%M%S).img"
      dd if="$PART" of="$BK" bs=4M status=none
      echo "Backup : $BK"
    else
      BK="(no backup)"
    fi

    dd if="$IMG" of="$PART" bs=4M iflag=count_bytes count="$WRITE_SIZE" conv=fsync status=progress
    sync

    H2=$(head -c "$WRITE_SIZE" "$PART" | sha256sum | cut -d' ' -f1)
    [ "$H1" = "$H2" ] || die "Verification of $T failed! Restore with: dd if=$BK of=$PART bs=4M"
    echo "Verification OK ($T)."
  done

  if [ "$REBOOT" -eq 1 ]; then
    if [ "$POWEROFF" -eq 1 ]; then
      echo "Powering off..."; sleep 2
      systemctl poweroff || poweroff
    else
      echo "Rebooting..."; sleep 2
      systemctl reboot || reboot
    fi
  fi
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  main "$@"
fi
