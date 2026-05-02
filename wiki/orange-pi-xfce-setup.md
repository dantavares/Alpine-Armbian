# Configuração de Interface Gráfica no Orange Pi PC (Allwinner H3)

## Hardware
- **Placa:** Orange Pi PC
- **SoC:** Allwinner H3
- **GPU:** Mali-400 MP2 (pp0 + pp1)
- **Driver GPU:** Lima (open source, kernel mainline)
- **Display:** sun4i-drm via HDMI

---

## O que foi instalado

### Xorg e drivers
```sh
apk add xorg-server xorg-server-common xinit
apk add xf86-video-fbdev xf86-input-evdev xf86-input-keyboard xf86-input-mouse
```

### Mesa / Aceleração 3D (Lima)
```sh
apk add mesa-dri-gallium mesa-gl mesa-egl mesa-gles \
        mesa-gbm libdrm mesa-demos
```

### XFCE e utilitários
```sh
apk add xfce4 xfce4-terminal dbus elogind polkit polkit-elogind
```

### Display Manager
```sh
apk add lightdm lightdm-gtk-greeter accountsservice
```

### Seat / Device Management
```sh
apk add eudev seatd
```

---

## Configuração do Xorg

Arquivo: `/etc/X11/xorg.conf.d/10-modesetting.conf`

```
Section "Device"
    Identifier  "Mali Lima"
    Driver      "modesetting"
    Option      "AccelMethod" "glamor"
    Option      "DRI"         "3"
    Option      "DRICard"     "/dev/dri/card1"
EndSection
```

> O **card0** é o sun4i-drm (display/HDMI) e o **card1** é o Lima (GPU Mali-400).

---

## Serviços ativados

```sh
# sysinit
rc-update add udev sysinit
rc-update add udev-trigger sysinit
rc-update add udev-settle sysinit

# default (boot)
rc-update add dbus default
rc-update add elogind default
rc-update add seatd default
rc-update add accountsservice default
rc-update add lightdm default
```

---

## Grupos do usuário

```sh
addgroup SEU_USUARIO input
addgroup SEU_USUARIO video
addgroup SEU_USUARIO audio
addgroup SEU_USUARIO render
addgroup SEU_USUARIO seat
```

---

## Kernel utilizado

O kernel em uso é o do **Armbian**, que oferece suporte mais completo ao hardware do H3 em comparação ao kernel ARM genérico do Alpine. Isso viabiliza o funcionamento do **Cedrus** (decodificação de vídeo por hardware via V4L2 stateless API).

---

## Notas importantes

- O Alpine não possui o pacote `libgbm` separado — o correto é `mesa-gbm`.
- O aviso `Failed to register cooling device` no dmesg é inofensivo.
- O LightDM iniciava mas travava sem o `accountsservice` e o `seatd`.
- O `plymouth` não existe no Alpine — o aviso no log do LightDM é ignorável.

---

## Mapa dos dispositivos DRM

| Dispositivo | Driver | Função |
|---|---|---|
| `/dev/dri/card0` | sun4i-drm | Controlador de display / HDMI |
| `/dev/dri/card1` | lima | GPU Mali-400 MP2 |
| `/dev/dri/renderD128` | lima | Nó de renderização 3D |

---

## Suporte OpenGL com Lima

| Recurso | Suporte |
|---|---|
| OpenGL ES 2.0 | ✅ |
| OpenGL 2.1 | ✅ |
| OpenGL 3.x | ❌ |
| Vulkan | ❌ |
| Compositor XFCE (Glamor) | ✅ |
| Vídeo HW decode | ✅ (Cedrus, funciona com kernel Armbian) |
