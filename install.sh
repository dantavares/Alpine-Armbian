#!/bin/bash
set -e

ORANGEPI_IP=$1
KERNEL_VERSION="6.18.24-current-sunxi"

if [ -z "$ORANGEPI_IP" ]; then
    echo "Usage: ./install.sh <orangepi-ip>"
    exit 1
fi

echo "==> Copying kernel..."
rsync -av output/vmlinuz-${KERNEL_VERSION} root@${ORANGEPI_IP}:/boot/

echo "==> Copying u-boot img..."
rsync -av u-boot/u-boot-armbian.bin root@${ORANGEPI_IP}:/boot/u-boot.bin

echo "==> Copying DTBs to dtbs-lts folder..."
rsync -av output/dtbs/ root@${ORANGEPI_IP}:/boot/dtbs-lts/

echo "==> Copying modules (excluding broken symlinks)..."
rsync -av --no-links \
    output/lib/modules/${KERNEL_VERSION}/ \
    root@${ORANGEPI_IP}:/lib/modules/${KERNEL_VERSION}/

echo "==> Configuring mkinitfs..."
ssh root@${ORANGEPI_IP} "cat > /etc/mkinitfs/mkinitfs.conf << 'EOF'
features=\"ata base ide scsi usb virtio ext4 mmc sunxi\"
EOF"

ssh root@${ORANGEPI_IP} "cat > /etc/mkinitfs/features.d/mmc.modules << 'EOF'
kernel/drivers/mmc
kernel/drivers/mmc/core/mmc_block.ko.gz
kernel/drivers/regulator
EOF"

ssh root@${ORANGEPI_IP} "cat > /etc/mkinitfs/features.d/sunxi.modules << 'EOF'
kernel/drivers/mmc/host/sunxi-mmc.ko.gz
EOF"

echo "==> Generating initramfs..."
ssh root@${ORANGEPI_IP} "mkinitfs -k ${KERNEL_VERSION}"

echo "==> Updating extlinux.conf..."
APPEND=$(ssh root@${ORANGEPI_IP} "cat /boot/extlinux/extlinux.conf | grep -m 1 append")
ssh root@${ORANGEPI_IP} "cat > /boot/extlinux/extlinux.conf << 'EOF'
menu title Alpine Linux
timeout 1

label sunxi
menu label Linux current-sunxi
kernel /vmlinuz-${KERNEL_VERSION}
initrd /initramfs-sunxi
fdtdir /dtbs-lts
$APPEND
EOF"

echo ""
echo "==> Verifying extlinux.conf..."
ssh root@${ORANGEPI_IP} "cat /boot/extlinux/extlinux.conf"
echo ""

echo "==> Updating u-boot..."
ssh root@${ORANGEPI_IP} "dd if=/boot/u-boot.bin of=/dev/mmcblk0 bs=8k seek=1"

echo "==> Installation complete!"
echo "    Review the output above before rebooting."
echo "    To reboot: ssh root@${ORANGEPI_IP} reboot"
