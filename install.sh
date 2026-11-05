#!/bin/bash
# Switch2Android installer / pemasang Switch2Android
# Installs sta-linux + a "Switch2Android" launcher in the GNOME/KDE/... app menu.
# Run as a normal user (it asks for sudo when needed).

set -euo pipefail

PREFIX="${PREFIX:-/usr/local}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
APPS="$DATA/applications"
ICONS="$DATA/icons"
BACKUP_DIR="$HOME/sta-backup"
PL="/dev/disk/by-partlabel"

# ---- language / bahasa
L=en
case "${LC_ALL:-${LANG:-}}" in id*) L=id ;; esac
t() { if [ "$L" = id ]; then echo "$2"; else echo "$1"; fi; }
die() { echo "$(t ERROR Galat): $*" >&2; exit 1; }
ask() { # ask "question en" "question id" -> 0 if yes
  [ "$ASSUME_YES" -eq 1 ] && return 0
  local a; read -r -p "$(t "$1" "$2") [y/N] " a
  case "$a" in y|Y|yes|YES|ya|Ya|YA) return 0 ;; *) return 1 ;; esac
}

usage() {
  t "Usage: bash install.sh [options] [/path/to/boot.img]
  --slot a|b|both   force the slot to flash (default: detect the active slot)
  --lang en|id      installer/launcher language
  --no-backup       skip backing up your boot partitions
  -y, --yes         answer yes to all questions
  --uninstall       remove Switch2Android
  -h, --help        this help" "Pemakaian: bash install.sh [opsi] [/jalur/ke/boot.img]
  --slot a|b|both   paksa slot yang di-flash (bawaan: deteksi slot aktif)
  --lang en|id      bahasa pemasang/peluncur
  --no-backup       lewati backup partisi boot
  -y, --yes         jawab ya untuk semua pertanyaan
  --uninstall       hapus Switch2Android
  -h, --help        bantuan ini"
}

IMG=""; SLOT=""; DO_BACKUP=1; UNINSTALL=0; ASSUME_YES=0
while [ $# -gt 0 ]; do
  case "$1" in
    --slot) [ $# -ge 2 ] || die "--slot"; SLOT="$2"; shift 2 ;;
    --lang) [ $# -ge 2 ] || die "--lang"; L="$2"; shift 2 ;;
    --no-backup) DO_BACKUP=0; shift ;;
    -y|--yes) ASSUME_YES=1; shift ;;
    --uninstall) UNINSTALL=1; shift ;;
    -h|--help) usage; exit 0 ;;
    -*) die "$(t "Unknown option" "Opsi tidak dikenal"): $1" ;;
    *) IMG="$1"; shift ;;
  esac
done
case "$L" in en|id) ;; *) L=en ;; esac

if [ "$(id -u)" -eq 0 ]; then SUDO=""; else SUDO="sudo"; fi

# ---- uninstall
if [ "$UNINSTALL" -eq 1 ]; then
  $SUDO rm -f "$PREFIX/bin/sta-linux" "$PREFIX/bin/sta-android"
  $SUDO rm -rf "$PREFIX/share/sta"
  rm -f "$APPS/switch2android.desktop" "$ICONS/switch2android.png"
  command -v update-desktop-database >/dev/null && update-desktop-database "$APPS" 2>/dev/null || true
  t "Switch2Android removed. Your backups in $BACKUP_DIR were kept." \
    "Switch2Android dihapus. Backup Anda di $BACKUP_DIR tetap disimpan."
  exit 0
fi

# ---- checks
[ "$(id -u)" -ne 0 ] || die "$(t "Run as a normal user, not root." "Jalankan sebagai pengguna biasa, bukan root.")"
for c in dd sha256sum blockdev od head stat readlink install; do
  command -v "$c" >/dev/null || die "$(t "Missing command" "Perintah tidak ada"): $c"
done
[ -z "$SUDO" ] || command -v sudo >/dev/null || die "$(t "sudo is required." "sudo diperlukan.")"
[ -f "$HERE/sta-linux.sh" ] && [ -f "$HERE/sta.png" ] || die "$(t "sta-linux.sh and sta.png must be next to install.sh." "sta-linux.sh dan sta.png harus satu folder dengan install.sh.")"

case "$SLOT" in ""|a|b|both) ;; *) die "--slot a|b|both" ;; esac
case "$SLOT" in a) SLOT_FLAGS="-a" ;; b) SLOT_FLAGS="-b" ;; both) SLOT_FLAGS="-a -b" ;; *) SLOT_FLAGS="" ;; esac

# ---- boot image
if [ -z "$IMG" ]; then
  read -r -e -p "$(t "Path to your Android boot.img: " "Jalur ke boot.img Android Anda: ")" IMG
fi
IMG="${IMG/#\~/$HOME}"
[ -f "$IMG" ] || die "$(t "File not found" "File tidak ditemukan"): $IMG"
[ "$(head -c 8 "$IMG")" = "ANDROID!" ] || die "$(t "That is not an Android boot image." "Itu bukan boot image Android.")"

# ---- terminal
TERM_CMD="${STA_TERMINAL:-}"
if [ -z "$TERM_CMD" ]; then
  for c in kgx gnome-terminal konsole xfce4-terminal alacritty kitty xterm; do
    command -v "$c" >/dev/null && { TERM_CMD="$c"; break; }
  done
fi
[ -n "$TERM_CMD" ] || die "$(t "No terminal emulator found. Set STA_TERMINAL=<command> and run again." "Terminal tidak ditemukan. Atur STA_TERMINAL=<perintah> lalu jalankan lagi.")"
case "$TERM_CMD" in
  gnome-terminal) EXEC="gnome-terminal -- $PREFIX/bin/sta-android" ;;
  kitty)          EXEC="kitty $PREFIX/bin/sta-android" ;;
  *)              EXEC="$TERM_CMD -e $PREFIX/bin/sta-android" ;;
esac

# ---- which partition will be overwritten?
echo
t "Checking which partition the launcher will overwrite..." "Memeriksa partisi yang akan ditimpa oleh peluncur..."
# shellcheck disable=SC2086
if ! TARGET=$($SUDO bash "$HERE/sta-linux.sh" -d $SLOT_FLAGS 2>&1); then
  echo "$TARGET"
  die "$(t "Could not detect the slot. Run again with --slot a or --slot b." "Slot tidak terdeteksi. Jalankan lagi dengan --slot a atau --slot b.")"
fi
echo "  $TARGET"
t "  This partition will be OVERWRITTEN with your Android boot.img whenever you use Switch2Android.
  It must be the slot that holds your Linux/UEFI boot image." "  Partisi ini akan DITIMPA dengan boot.img Android setiap Anda memakai Switch2Android.
  Partisi itu harus slot yang berisi image boot Linux/UEFI Anda."
ask "Is this correct?" "Apakah ini benar?" || die "$(t "Aborted. Nothing was changed." "Dibatalkan. Tidak ada yang diubah.")"

# ---- backup boot partitions
if [ "$DO_BACKUP" -eq 1 ]; then
  mkdir -p "$BACKUP_DIR"
  STAMP=$(date +%Y%m%d-%H%M%S); N=0
  for p in boot boot_a boot_b; do
    if [ -b "$PL/$p" ]; then
      $SUDO dd if="$PL/$p" bs=4M status=none > "$BACKUP_DIR/$p-$STAMP.img"
      echo "  $(t "Backup" "Backup"): $BACKUP_DIR/$p-$STAMP.img"
      N=$((N+1))
    fi
  done
  [ "$N" -gt 0 ] && t "Keep these files safe, also outside the device: they restore your UEFI." \
                      "Simpan file ini dengan aman, juga di luar perangkat: file ini memulihkan UEFI Anda."
fi

# ---- install files
$SUDO install -Dm755 "$HERE/sta-linux.sh" "$PREFIX/bin/sta-linux"
$SUDO install -Dm644 "$IMG" "$PREFIX/share/sta/boot.img"
install -Dm644 "$HERE/sta.png" "$ICONS/switch2android.png"

LAUNCHER=$(mktemp)
cat > "$LAUNCHER" <<LAUNCH
#!/bin/bash
echo "=== Switch2Android ==="
echo
echo "$(t "Press any key to continue ..." "Tekan tombol apa saja untuk melanjutkan ...")"
echo "$(t "Or close this window to cancel" "Atau tutup jendela ini untuk membatalkan")"
read -n 1 -s -r
echo
sudo $PREFIX/bin/sta-linux -q -B $SLOT_FLAGS
echo
read -r -p "$(t "Press Enter to close..." "Tekan Enter untuk menutup...")"
LAUNCH
$SUDO install -Dm755 "$LAUNCHER" "$PREFIX/bin/sta-android"
rm -f "$LAUNCHER"

mkdir -p "$APPS"
cat > "$APPS/switch2android.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=Switch2Android
Comment=$(t "Switch from Linux to Android" "Pindah dari Linux ke Android")
Exec=$EXEC
Icon=$ICONS/switch2android.png
Terminal=false
Categories=System;
DESKTOP
command -v update-desktop-database >/dev/null && update-desktop-database "$APPS" 2>/dev/null || true

echo
t "Done! Open your app menu and start \"Switch2Android\"." \
  "Selesai! Buka menu aplikasi dan jalankan \"Switch2Android\"."
t "To update the Android image later: bash install.sh /path/to/new/boot.img" \
  "Untuk memperbarui image Android nanti: bash install.sh /jalur/ke/boot.img-baru"
