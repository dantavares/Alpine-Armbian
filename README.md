# Armbian Kernel for Alpine Linux — Orange Pi PC

## Why Alpine Linux instead of Armbian?

Armbian is an excellent project, but it ships a full Debian/Ubuntu-based system
that can feel heavy for a board with only 1GB of RAM. Alpine Linux offers a
compelling alternative:

| | Alpine Linux | Armbian (Debian/Ubuntu) |
|---|---|---|
| Base image size | ~50MB | ~500MB+ |
| RAM usage at idle | ~30MB | ~150MB+ |
| Boot time | ~5s | ~20s+ |
| Package manager | `apk` (fast, minimal) | `apt` (heavier) |
| Init system | OpenRC (simple) | systemd (complex) |
| Security | musl libc, hardened by default | glibc standard |
| Docker support | Native, first-class | Available |
| Customization | Minimal base, add only what you need | Full desktop-oriented base |

Alpine Linux is ideal for **headless servers, Docker hosts, and lightweight
services** — exactly what most people use a single-board computer for.
The only downside is the limited hardware support in the default `armhf` kernel,
which is exactly what this project solves by using the Armbian kernel.

**Best of both worlds:** Alpine's lightweight userspace with Armbian's
fully-featured kernel.

---

## Why use the Armbian kernel?

The default Alpine Linux `armhf` kernel lacks several critical drivers for
Allwinner H3/H2+ SoCs used on the Orange Pi PC and similar boards:

| Feature | Alpine kernel | Armbian kernel |
|---|---|---|
| CPU thermal sensor | ❌ | ✅ |
| HDMI output | ❌ | ✅ |
| Sunxi Cedrus video decoder | ❌ | ✅ |
| Full H3/H2+ hardware support | ❌ | ✅ |

Rather than maintaining a custom kernel build, the most practical solution is
to extract the `current-sunxi` kernel directly from an Armbian image — it is
actively maintained, regularly updated, and fully supports the hardware out
of the box.

---

## Compatibility

> **Tested on:** Orange Pi PC (Allwinner H3)

This project was developed and tested on the **Orange Pi PC**, and a ready-to-use
Alpine base image is provided for it. However, the scripts are **board-agnostic**
by design:

- `extract-armbian.sh` works with any Armbian `.img.xz` image regardless of board
- `install.sh` installs via SSH on any Alpine Linux system regardless of board

This means the scripts should work on **any ARMv7 board supported by Armbian**,
as long as:

1. Alpine Linux is already installed and running on the board (even with the original Alpine kernel)
2. The correct Armbian image for that board is used for extraction
3. SSH access is available

**Boards likely to work** (not tested — community feedback welcome):

| Board | SoC | Armbian image to use |
|---|---|---|
| Orange Pi One | Allwinner H3 | `Armbian_*_Orangepipc_*` |
| Orange Pi Lite | Allwinner H3 | `Armbian_*_Orangepilite_*` |
| Orange Pi Zero | Allwinner H2+ | `Armbian_*_Orangepizero_*` |
| NanoPi M1 | Allwinner H3 | `Armbian_*_NanoPiM1_*` |
| NanoPi NEO | Allwinner H3 | `Armbian_*_NanoPiNeo_*` |
| BananaPi M2 Plus | Allwinner H3 | `Armbian_*_BananaPiM2Plus_*` |

> If you test on a different board, please open an issue or PR with your results!

---

## Overview

This folder contains two scripts:

- **`extract-armbian.sh`** — Extracts kernel, DTBs, modules and U-Boot from an Armbian `.img.xz` image
- **`install.sh`** — Installs the extracted files on Alpine Linux via SSH

---

## Requirements

### PC (Linux)
- `xz` — to decompress the Armbian image
- `losetup` — to mount the image (usually pre-installed)
- `rsync` — to copy files efficiently
- `sudo` — required for losetup and dd

### Target board
- Alpine Linux installed and running (any kernel)
- SSH access
- `rsync` installed:
```sh
apk add rsync
```

---

## Base SD Card Image (Orange Pi PC only)

A ready-to-use 2GB Alpine Linux base image is provided for the Orange Pi PC.
It includes the base system pre-configured and ready to receive the Armbian kernel.

For other boards, install Alpine Linux manually following the
[Alpine Linux ARM installation guide](https://wiki.alpinelinux.org/wiki/Alpine_Linux_on_ARM)
and then use `install.sh` to apply the Armbian kernel.

### Flashing the base image

**Linux:**
```sh
gunzip -c alpine-orangepi-base.img.gz | sudo dd of=/dev/sdX bs=4M status=progress
sync
```

**Windows/Mac:** Use balenaEtcher.

> Replace `/dev/sdX` with your SD card device.

### ⚠️ Expanding the root partition

The base image is 2GB. If your SD card is larger, **you must expand the root
partition manually** before booting, otherwise the extra space will be unused.

**On Linux PC, using parted (recommended):**
```sh
sudo parted /dev/sdX resizepart 3 100%
sudo e2fsck -f /dev/sdX3
sudo resize2fs /dev/sdX3
```

**Or using fdisk:**
```sh
sudo fdisk /dev/sdX
# Delete partition 3 and recreate using all available space:
# d → 3
# n → p → 3 → <accept default start> → <accept default end>
# w
```

Then resize the filesystem after first boot on the board:
```sh
resize2fs /dev/mmcblk0p3
```

---

## First Access and SSH Setup

Before running `install.sh`, SSH access to the board must be working from your PC.

### Using the provided base image

The base image allows **passwordless root SSH login** out of the box — no setup
needed. Simply connect the board to the network, find the IP and connect:

```sh
ssh root@<board-ip>
```

> **Security note:** Set a root password as soon as possible after installation:
> ```sh
> passwd root
> ```

### Using your own Alpine installation

If you installed Alpine yourself, make sure SSH is running and accessible:

```sh
# On the board
rc-update add sshd
rc-service sshd start
```

If your Alpine install requires a password for SSH, copy your public key from
the PC to avoid being prompted during the install script:

```sh
# On the PC — generate a key pair if you don't have one yet
ssh-keygen -t ed25519

# Copy the public key to the board
ssh-copy-id root@<board-ip>
```

---

## Step by Step

### 1. Download the Armbian image for your board

Get the latest `current` image from:
```
https://www.armbian.com/download/
```

Download the `.img.xz` file for your board, for example:
```
Armbian_24.11_Orangepipc_bookworm_current_6.12.8.img.xz
```

### 2. Extract files from the Armbian image

```sh
chmod +x extract-armbian.sh
./extract-armbian.sh Armbian_24.11_Orangepipc_bookworm_current_6.12.8.img.xz
```

Example output:
```
==> Decompressing image...
==> Setting up loop device... /dev/loop0
==> Partitions found: /dev/loop0p1
==> Kernel version detected: 6.12.8-current-sunxi
==> Extracting kernel...
==> Extracting DTBs...
==> Extracting modules...
==> Extracting U-Boot...
==> Updating KERNEL_VERSION in install.sh...
==> Cleaning up temporary image...

==> Extraction complete!
    Kernel:  output/vmlinuz-6.12.8-current-sunxi
    DTBs:    output/dtbs/
    Modules: output/lib/modules/6.12.8-current-sunxi/
    U-Boot:  u-boot/u-boot-armbian.bin

    install.sh updated with KERNEL_VERSION=6.12.8-current-sunxi
    Run: ./install.sh <board-ip>
```

### 3. Flash and expand the base image (Orange Pi PC only)

```sh
# Flash the base image
gunzip -c alpine-orangepi-base.img.gz | sudo dd of=/dev/sdX bs=4M status=progress
sync

# Expand root partition (if SD card > 2GB)
sudo parted /dev/sdX resizepart 3 100%
sudo e2fsck -f /dev/sdX3
sudo resize2fs /dev/sdX3
```

For other boards: install Alpine manually and proceed to step 4.

### 4. Boot the board and connect via SSH

Insert the SD card, connect network cable and power on.
Find the IP on your router or via serial connection.

### 5. Install the Armbian kernel

```sh
chmod +x install.sh
./install.sh <board-ip>
```

The script will:
1. Copy the kernel to `/boot/`
2. Copy all DTBs to `/boot/dtbs-lts/`
3. Copy modules to `/lib/modules/<kernel-version>/`
4. Configure `mkinitfs` for Sunxi MMC support
5. Generate the initramfs
6. Update `extlinux.conf` with the new kernel
7. Flash the Armbian U-Boot to the SD card

### 6. Review extlinux.conf before rebooting

```sh
ssh root@<board-ip> cat /boot/extlinux/extlinux.conf
```

Expected output:
```
menu title Alpine Linux
timeout 1

label sunxi
menu label Linux current-sunxi
kernel /vmlinuz-6.12.8-current-sunxi
initrd /initramfs-sunxi
fdtdir /dtbs-lts
append root=UUID=<uuid> modules=sd-mod,usb-storage,ext4 quiet rootfstype=ext4
```

### 7. Reboot

```sh
ssh root@<board-ip> reboot
```

### 8. Verify

```sh
# Kernel version
uname -r
# Expected: 6.12.8-current-sunxi

# CPU temperature
awk '{printf "CPU Temp: %.1f°C\n", $1/1000}' /sys/class/thermal/thermal_zone0/temp

# HDMI
dmesg | grep -iE "hdmi|drm" | grep -i "bound\|initialized"
```

---

## Updating to a new Armbian kernel version

When Armbian releases a new kernel, simply:

```sh
# Extract from new Armbian image
./extract-armbian.sh Armbian_<new-version>_Orangepipc_current.img.xz

# Reinstall on the board
./install.sh <board-ip>
```

The `extract-armbian.sh` script automatically updates `KERNEL_VERSION` in
`install.sh` — no manual editing needed.

---

## Troubleshooting

| Issue | Cause | Solution |
|---|---|---|
| Kernel not found at boot | Wrong path in extlinux.conf | Check `kernel /vmlinuz-...` has no `/boot/` prefix |
| No space left during install | Root partition not expanded | Expand partition before first boot |
| `rsync: not found` on board | Package not installed | Run `apk add rsync` |
| U-Boot not updated | `dd` failed | Check `/dev/mmcblk0` exists and rerun install |
| HDMI no signal | Cable not connected at boot | Connect HDMI before powering on |
| Temperature not available | Wrong kernel | Verify `uname -r` shows `current-sunxi` |
| Board not booting after install | Incompatible U-Boot | Try without flashing U-Boot — comment out the `dd` line in `install.sh` |

---

## Contributing

If you test this on a board other than the Orange Pi PC, please open an issue
or PR with:
- Board name and SoC
- Armbian image used
- Whether it worked or what failed

This will help build a tested compatibility list for the community.

---

## License

MIT License — feel free to use, modify and distribute.
