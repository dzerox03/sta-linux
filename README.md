# Switch2Android

**English** · [Bahasa Indonesia](#bahasa-indonesia)

Switch from Linux to Android with one click on a dual-boot tablet or phone.
Switch2Android writes your Android `boot.img` to the boot partition and reboots, so the device starts Android.

This is a Linux port of [n00b69/sta](https://github.com/n00b69/sta) (made by BIBARUB, a Windows tool). It is a rewrite in shell, not a copy of the original code. Credit for the idea goes to the original author.

> ⚠️ **Warning.** This tool writes directly to a boot partition. A wrong slot or a wrong `boot.img` can leave your device unable to boot. Back up your boot partitions first (the installer offers to do it) and make sure you can reach fastboot. You use it at your own risk; the authors are not responsible for any damage.

## Tested on

- Xiaomi Pad 5 (nabu), Arch Linux ARM, GNOME, booted through UEFI with the rEFInd boot menu. Going back from Android to Linux is done with [WOA Helper](https://github.com/n00b69/woa-helper) (not included).
- Other devices with A/B boot partitions (`boot_a` / `boot_b`) and the same kind of dual-boot setup may work, but are **untested**.

## How it works

Your Linux boots from a UEFI image stored in a boot partition (for example `boot_a`). Android boots from a normal Android `boot.img`. Switch2Android overwrites the **active** boot partition with your Android `boot.img` and reboots. Going back to Linux means writing the UEFI image to that partition again ([WOA Helper](https://github.com/n00b69/woa-helper) does this).

The active slot is read from the GPT partition attributes, as in the original tool. If a partition simply called `boot` exists, it is used instead.

## Requirements

- Linux with `bash`, `dd`, `sha256sum`, `blockdev`, `od`, `sudo` (all standard) and a terminal emulator (`kgx`, `gnome-terminal`, `konsole`, `xfce4-terminal`, `alacritty`, `kitty` or `xterm`).
- The `boot.img` of the Android version **installed on your device**, from your own firmware package. Do not use a `boot.img` from another device or version, and do not share yours: it is tied to your device and your firmware.

## Install

```bash
tar xf switch2android.tar.gz
cd switch2android
bash install.sh /path/to/boot.img
```

The installer will:

1. check that `boot.img` is an Android boot image,
2. show **which partition will be overwritten** and ask you to confirm (it must be the slot that holds your Linux/UEFI image),
3. back up your boot partitions to `~/sta-backup/`,
4. install the program and add **Switch2Android** to your app menu.

Options: `--slot a|b|both`, `--lang en|id`, `--no-backup`, `-y`, `--uninstall`. If your terminal is not detected, run `STA_TERMINAL=<command> bash install.sh ...`.

Check what would be flashed at any time (changes nothing):

```bash
sudo sta-linux -d
```

## Use

Open your app menu, start **Switch2Android**, press any key, enter your password. When you see `Verification OK`, the device reboots into Android. Close the window before pressing a key to cancel.

To go back to Linux, use [WOA Helper](https://github.com/n00b69/woa-helper) from Android as usual.

### Command line

`sudo sta-linux [options]` (the options follow the Windows original, plus a few extras):

| Option | Meaning |
|---|---|
| `-p <file>` | path to the boot image (default `/usr/local/share/sta/boot.img`) |
| `-a` / `-b` | flash slot A / slot B (`-a -b` for both) |
| `-f` | full flash: write the whole file, skip header parsing |
| `-t` | write only the size in the boot image header (default writes the whole file, which keeps the AVB footer) |
| `-y` | flash even if the file is not an Android boot image |
| `-n` | do not reboot |
| `-s` | power off instead of reboot |
| `-q` | quiet: no summary, no confirmation |
| `-B` | do not back up the old partition |
| `-d` | only show the target partition |

## Update the Android image

After a firmware update, install the new `boot.img`:

```bash
bash install.sh /path/to/new/boot.img
```

## Recovery

If the device does not boot, enter fastboot (on the Xiaomi Pad 5: Volume Down + Power), connect it to a PC and flash your backup, for example:

```bash
fastboot flash boot_a boot_a-YYYYMMDD-HHMMSS.img
```

Keep a copy of the files in `~/sta-backup/` outside the device.

## Uninstall

```bash
bash install.sh --uninstall
```

Your backups are kept.

## Troubleshooting

- **"No active boot partition found"**: run `bash install.sh --slot a` (or `b`).
- **"Not an Android boot image"**: the file is not a boot image; get `boot.img` from your firmware package.
- **The icon opens nothing**: your terminal may not be supported; reinstall with `STA_TERMINAL=<command>`.
- **The icon does not show up**: log out and in again.

Prefer a ready-made archive? Download `switch2android.tar.gz` from the [Releases](https://github.com/dzerox03/sta-linux/releases) page.

---

# Bahasa Indonesia

[English](#switch2android) · **Bahasa Indonesia**

Pindah dari Linux ke Android dengan satu klik di tablet atau ponsel dual boot.
Switch2Android menulis `boot.img` Android ke partisi boot lalu me-reboot, sehingga perangkat menyala ke Android.

Ini adalah port Linux dari [n00b69/sta](https://github.com/n00b69/sta) (dibuat oleh BIBARUB, alat untuk Windows). Ini ditulis ulang dalam shell, bukan salinan kode aslinya. Kredit ide untuk pembuat aslinya.

> ⚠️ **Peringatan.** Alat ini menulis langsung ke partisi boot. Slot yang salah atau `boot.img` yang salah bisa membuat perangkat tidak bisa boot. Backup partisi boot Anda dulu (pemasang menawarkannya) dan pastikan Anda bisa masuk fastboot. Pemakaian sepenuhnya risiko Anda; pembuatnya tidak bertanggung jawab atas kerusakan apa pun.

## Sudah diuji di

- Xiaomi Pad 5 (nabu), Arch Linux ARM, GNOME, boot lewat UEFI dengan menu rEFInd. Kembali dari Android ke Linux dilakukan dengan [WOA Helper](https://github.com/n00b69/woa-helper) (tidak disertakan).
- Perangkat lain dengan partisi boot A/B (`boot_a` / `boot_b`) dan setup dual boot yang sama mungkin bisa dipakai, tetapi **belum diuji**.

## Cara kerja

Linux Anda boot dari image UEFI yang disimpan di partisi boot (misalnya `boot_a`). Android boot dari `boot.img` Android biasa. Switch2Android menimpa partisi boot yang **aktif** dengan `boot.img` Android Anda lalu reboot. Untuk kembali ke Linux, image UEFI ditulis lagi ke partisi itu ([WOA Helper](https://github.com/n00b69/woa-helper) melakukannya).

Slot aktif dibaca dari atribut partisi GPT, seperti alat aslinya. Kalau ada partisi bernama `boot` saja, partisi itu yang dipakai.

## Kebutuhan

- Linux dengan `bash`, `dd`, `sha256sum`, `blockdev`, `od`, `sudo` (semuanya standar) dan emulator terminal (`kgx`, `gnome-terminal`, `konsole`, `xfce4-terminal`, `alacritty`, `kitty` atau `xterm`).
- `boot.img` dari versi Android yang **terpasang di perangkat Anda**, diambil dari paket firmware Anda sendiri. Jangan pakai `boot.img` dari perangkat atau versi lain, dan jangan bagikan milik Anda: file itu terikat pada perangkat dan firmware Anda.

## Pemasangan

```bash
tar xf switch2android.tar.gz
cd switch2android
bash install.sh /jalur/ke/boot.img
```

Pemasang akan:

1. memeriksa bahwa `boot.img` adalah boot image Android,
2. menampilkan **partisi yang akan ditimpa** dan meminta konfirmasi (harus slot yang berisi image Linux/UEFI Anda),
3. mem-backup partisi boot Anda ke `~/sta-backup/`,
4. memasang program dan menambahkan **Switch2Android** ke menu aplikasi.

Opsi: `--slot a|b|both`, `--lang en|id`, `--no-backup`, `-y`, `--uninstall`. Kalau terminal Anda tidak terdeteksi, jalankan `STA_TERMINAL=<perintah> bash install.sh ...`.

Cek apa yang akan di-flash kapan saja (tidak mengubah apa pun):

```bash
sudo sta-linux -d
```

## Pemakaian

Buka menu aplikasi, jalankan **Switch2Android**, tekan tombol apa saja, masukkan password. Saat muncul `Verification OK`, perangkat reboot ke Android. Tutup jendela sebelum menekan tombol untuk membatalkan.

Untuk kembali ke Linux, pakai [WOA Helper](https://github.com/n00b69/woa-helper) dari Android seperti biasa.

### Baris perintah

`sudo sta-linux [opsi]` (opsinya mengikuti versi Windows asli, ditambah beberapa tambahan):

| Opsi | Arti |
|---|---|
| `-p <file>` | jalur boot image (bawaan `/usr/local/share/sta/boot.img`) |
| `-a` / `-b` | flash slot A / slot B (`-a -b` untuk keduanya) |
| `-f` | flash penuh: tulis seluruh file, lewati pembacaan header |
| `-t` | tulis hanya sebesar ukuran di header boot image (bawaan menulis seluruh file, sehingga footer AVB terjaga) |
| `-y` | flash walau file bukan boot image Android |
| `-n` | jangan reboot |
| `-s` | matikan perangkat, bukan reboot |
| `-q` | senyap: tanpa ringkasan dan konfirmasi |
| `-B` | jangan backup partisi lama |
| `-d` | hanya tampilkan partisi target |

## Memperbarui image Android

Setelah pembaruan firmware, pasang `boot.img` yang baru:

```bash
bash install.sh /jalur/ke/boot.img-baru
```

## Pemulihan

Kalau perangkat tidak mau boot, masuk fastboot (di Xiaomi Pad 5: Volume Bawah + Power), sambungkan ke PC, lalu flash backup Anda, misalnya:

```bash
fastboot flash boot_a boot_a-YYYYMMDD-HHMMSS.img
```

Simpan salinan file di `~/sta-backup/` di luar perangkat.

## Menghapus

```bash
bash install.sh --uninstall
```

Backup Anda tetap disimpan.

## Pemecahan masalah

- **"No active boot partition found"**: jalankan `bash install.sh --slot a` (atau `b`).
- **"Not an Android boot image"**: file itu bukan boot image; ambil `boot.img` dari paket firmware Anda.
- **Ikon tidak membuka apa pun**: terminal Anda mungkin tidak didukung; pasang ulang dengan `STA_TERMINAL=<perintah>`.
- **Ikon tidak muncul**: logout lalu login lagi.

Lebih suka arsip siap pakai? Unduh `switch2android.tar.gz` dari halaman [Releases](https://github.com/dzerox03/sta-linux/releases).
