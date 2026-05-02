#!/bin/bash
set -e

ARMBIAN_IMAGE=$1

if [ -z "$ARMBIAN_IMAGE" ]; then
    echo "Usage: ./extract-armbian.sh <armbian-image.img.xz>"
    exit 1
fi

# Descompactar se necessário
if [[ "$ARMBIAN_IMAGE" == *.xz ]]; then
    echo "==> Decompressing image..."
    xz -dk "$ARMBIAN_IMAGE"
    ARMBIAN_IMAGE="${ARMBIAN_IMAGE%.xz}"
fi

echo "==> Setting up loop device..."
LOOP=$(sudo losetup -f --show -P "$ARMBIAN_IMAGE")
echo "    Loop device: $LOOP"

# Listar partições encontradas
echo "==> Partitions found:"
ls ${LOOP}p*

# Criar pontos de montagem temporários
MOUNT_BOOT=$(mktemp -d)
MOUNT_ROOT=$(mktemp -d)

echo "==> Mounting partitions..."
sudo mount ${LOOP}p1 "$MOUNT_BOOT"
sudo mount ${LOOP}p2 "$MOUNT_ROOT" 2>/dev/null || sudo mount ${LOOP}p1 "$MOUNT_ROOT"

# Detectar estrutura — single partition ou dual partition
if [ -d "$MOUNT_ROOT/lib/modules" ]; then
    ROOT="$MOUNT_ROOT"
    BOOT="$MOUNT_ROOT/boot"
else
    ROOT="$MOUNT_ROOT"
    BOOT="$MOUNT_BOOT"
fi

echo "==> Boot path: $BOOT"
echo "==> Root path: $ROOT"

# Detectar versão do kernel
KERNEL_VERSION=$(ls $ROOT/lib/modules/ | head -1)
echo "==> Kernel version detected: $KERNEL_VERSION"

# Criar pastas de output
mkdir -p output/dtbs
mkdir -p output/lib/modules
mkdir -p u-boot

echo "==> Extracting kernel..."
cp $BOOT/vmlinuz-${KERNEL_VERSION} output/

echo "==> Extracting DTBs..."
rsync -av --no-links $BOOT/dtb/ output/dtbs/ 2>/dev/null || \
rsync -av --no-links $BOOT/dtbs/ output/dtbs/ 2>/dev/null || \
rsync -av --no-links $BOOT/dtb-${KERNEL_VERSION}/ output/dtbs/ 2>/dev/null
# Flatten DTBs — copy only allwinner DTBs to root of output/dtbs
find output/dtbs -name "*.dtb" | xargs -I{} cp {} output/dtbs/ 2>/dev/null || true

echo "==> Extracting modules..."
rsync -av --no-links \
    $ROOT/lib/modules/${KERNEL_VERSION}/ \
    output/lib/modules/${KERNEL_VERSION}/

echo "==> Extracting U-Boot..."
# U-Boot está gravado diretamente no disco, offset 8k (seek=1 com bs=8k)
sudo dd if=${LOOP} of=u-boot/u-boot-armbian.bin bs=8k skip=1 count=100 status=progress

echo "==> Updating KERNEL_VERSION in install.sh..."
sed -i "s|KERNEL_VERSION=.*|KERNEL_VERSION=\"${KERNEL_VERSION}\"|" install.sh

echo "==> Unmounting..."
sudo umount "$MOUNT_BOOT" 2>/dev/null || true
sudo umount "$MOUNT_ROOT" 2>/dev/null || true
sudo losetup -d "$LOOP"
rm -rf "$MOUNT_BOOT" "$MOUNT_ROOT"
rm -rf "$ARMBIAN_IMAGE"

echo ""
echo "==> Extraction complete!"
echo ""
echo "    Kernel:  output/vmlinuz-${KERNEL_VERSION}"
echo "    DTBs:    output/dtbs/"
echo "    Modules: output/lib/modules/${KERNEL_VERSION}/"
echo "    U-Boot:  u-boot/u-boot-armbian.bin"
echo ""
echo "    install.sh updated with KERNEL_VERSION=${KERNEL_VERSION}"
echo ""
echo "    Run: ./install.sh <orangepi-ip>"
