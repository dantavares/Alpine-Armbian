# Wiki — Alpine Linux no Orange Pi PC

## Índice

1. [Hardware](#hardware)
2. [Pré-requisitos](#pré-requisitos)
3. [Gravando a imagem no cartão SD](#gravando-a-imagem-no-cartão-sd)
4. [Configurando o bootloader](#configurando-o-bootloader)
5. [Primeira inicialização](#primeira-inicialização)
6. [Configuração inicial do sistema](#configuração-inicial-do-sistema)
7. [Configuração de rede IPv4 e IPv6](#configuração-de-rede-ipv4-e-ipv6)
8. [ZRAM](#zram)
9. [Montagem de disco externo no boot](#montagem-de-disco-externo-no-boot)
10. [Docker](#docker)

---

## Hardware

| Componente | Especificação |
|---|---|
| Placa | Orange Pi PC |
| SoC | Allwinner H3 (ARMv7) |
| RAM | 1 GB |
| Armazenamento boot | Cartão microSD |

---

## Pré-requisitos

- Cartão microSD (mínimo 4 GB, recomendado classe 10 ou A1)
- Computador para gravar a imagem (Linux, Windows ou Mac)
- Cabo serial UART ou monitor + teclado USB
- Fonte de alimentação 5V/2A
- Kernel e U-Boot do Armbian para Orange Pi PC

> **Nota sobre o kernel:** O kernel padrão do Alpine `armhf` não possui suporte a sensor térmico, HDMI, Cedrus e outros recursos do H3. A solução mais prática é utilizar o kernel do projeto **Armbian** (`current-sunxi`), que já vem compilado com todos os drivers necessários para o hardware.

---

## Gravando a imagem no cartão SD

### 1. Baixar a imagem

Acesse o repositório oficial do Alpine Linux e baixe a variante `armhf` (ARMv7 hard float):

```
https://dl-cdn.alpinelinux.org/alpine/latest-stable/releases/armhf/
```

Baixe o arquivo:
```
alpine-uboot-<versão>-armhf.img.gz
```

### 2. Gravar no cartão SD

**Linux:**
```sh
gunzip -c alpine-uboot-*.img.gz | sudo dd of=/dev/sdX bs=4M status=progress
sync
```

> Substitua `/dev/sdX` pelo dispositivo correto do seu cartão SD.

**Windows/Mac:** Use o balenaEtcher — descompacte o `.gz` antes de gravar.

---

## Configurando o bootloader

### 1. Montar a partição boot

```sh
sudo mount /dev/sdX1 /mnt
```

### 2. Configurar o extlinux.conf

```sh
sudo nano /mnt/extlinux/extlinux.conf
```

Conteúdo funcional utilizado nesta instalação:

```
menu title Alpine Linux
timeout 1

label sunxi
menu label Linux current-sunxi
kernel /vmlinuz-6.18.24-current-sunxi
initrd /initramfs-sunxi
fdtdir /dtbs-lts
append root=UUID=<UUID-da-partição-root> modules=sd-mod,usb-storage,ext4 quiet rootfstype=ext4
```

> Para obter o UUID da partição root:
> ```sh
> sudo blkid /dev/sdX2
> ```

### 3. Desmontar o cartão

```sh
sudo umount /mnt
```

---

## Primeira inicialização

Insira o cartão SD no Orange Pi PC e ligue. Conecte via serial UART se não houver monitor:

- **Baud rate:** 115200
- **Ferramentas:** `minicom`, `picocom` ou PuTTY

O sistema iniciará e solicitará login:

```
localhost login: root
```

> Sem senha na primeira inicialização.

---

## Configuração inicial do sistema

### 1. Executar o setup interativo

```sh
setup-alpine
```

O script configura:

- Teclado e idioma
- Nome do host
- Rede (eth0)
- Senha do root
- Servidor NTP
- Repositórios de pacotes
- Instalação no disco

Quando perguntado sobre disco, escolha instalação permanente no SD:
```
mmcblk0  →  sys
```

> **Swap:** Não foi configurada partição de swap. O ZRAM é utilizado como alternativa em RAM (ver seção [ZRAM](#zram)).

### 2. Atualizar pacotes

```sh
apk update && apk upgrade
```

### 3. Instalar utilitários básicos

```sh
apk add nano curl wget openssh
```

### 4. Habilitar SSH

```sh
rc-update add sshd
rc-service sshd start
```

---

## Configuração de rede IPv4 e IPv6

### Problema

O Alpine não obtinha rota default IPv6 via SLAAC. A causa é que o Docker habilita `net.ipv6.conf.eth0.forwarding=1`, e com esse valor ativo o kernel ignora os Router Advertisements com `accept_ra=1`, fazendo a rota default expirar imediatamente.

### 1. Configurar a interface de rede

```sh
nano /etc/network/interfaces
```

```sh
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
iface eth0 inet6 auto
```

O `inet6 auto` habilita o SLAAC para obter o endereço e gateway IPv6 automaticamente.

### 2. Corrigir o accept_ra

Com `forwarding=1`, é necessário `accept_ra=2` para o kernel aceitar os Router Advertisements:

```sh
nano /etc/sysctl.conf
```

Adicione:

```
net.ipv6.conf.eth0.accept_ra=2
```

Aplique:

```sh
sysctl -p
rc-service networking restart
```

### 3. Verificar

```sh
ip -6 route show default
ping6 -c 3 google.com
```

---

## ZRAM

O ZRAM cria um dispositivo de swap comprimido na RAM, essencial para compensar a ausência de partição de swap no Orange Pi PC com 1 GB de RAM.

### 1. Instalar

```sh
apk add zram-init
```

### 2. Carregar o módulo do kernel

```sh
modprobe zram
```

Habilitar no boot:

```sh
echo "zram" >> /etc/modules
```

> Para verificar se o módulo está disponível:
> ```sh
> find /lib/modules/$(uname -r) -name "zram*"
> ```

### 3. Configurar

```sh
nano /etc/conf.d/zram-init
```

```sh
num_devices="1"
type0="swap"
size0="512"       # em MB, sem sufixo M
algo0="lzo-rle"   # algoritmo padrão do kernel H3
flag0="100"       # prioridade do swap, somente o número
```

> Para verificar os algoritmos disponíveis no seu kernel:
> ```sh
> cat /sys/block/zram0/comp_algorithm
> ```

### 4. Habilitar no boot

```sh
rc-service zram-init start
rc-update add zram-init boot
```

### 5. Verificar

```sh
swapon -s
zramctl
```

### Observações importantes

| Ponto | Detalhe |
|---|---|
| `size0` | Somente número em MB, sem sufixo `M` |
| `flag0` | Somente o número da prioridade, sem `-p` |
| Módulo | Deve ser carregado antes do serviço via `/etc/modules` |

---

## Montagem de disco externo no boot

Quando há um disco externo (HD ou SSD via USB) que precisa ser montado antes do Docker iniciar, é necessário criar um serviço OpenRC dedicado e configurar a dependência corretamente.

### Problema

O fstab monta os volumes automaticamente, mas não garante a ordem em relação ao Docker. Se o Docker subir antes do disco estar montado, os volumes dos containers ficam indisponíveis.

### 1. Configurar o fstab com noauto

Adicione `noauto` para impedir a montagem automática pelo fstab, deixando o OpenRC responsável:

```sh
nano /etc/fstab
```

```
/dev/sda1 /mnt/sda1 ext4 nofail,lazytime,rw,noauto 0   2
```

### 2. Criar o serviço de montagem

```sh
nano /etc/init.d/mount-sda1
```

```sh
#!/sbin/openrc-run

description="Mount /dev/sda1"

depend() {
    need localmount
    before docker
}

start() {
    ebegin "Mounting /dev/sda1"
    mount /dev/sda1 /mnt/sda1
    eend $?
}

stop() {
    ebegin "Unmounting /dev/sda1"
    umount /mnt/sda1
    eend $?
}
```

```sh
chmod +x /etc/init.d/mount-sda1
rc-update add mount-sda1 boot
```

### 3. Adicionar dependência no Docker

Para garantir que o Docker aguarde a montagem sem editar o script principal (que seria sobrescrito em atualizações):

```sh
nano /etc/conf.d/docker
```

Adicione ao final:

```sh
rc_need="mount-sda1"
```

### 4. Verificar

```sh
rc-service mount-sda1 start
mount | grep sda1
rc-status boot | grep -E "docker|sda1"
```

---

## Docker

### 1. Habilitar o repositório Community

```sh
nano /etc/apk/repositories
```

Certifique-se de que a linha `community` está descomentada:

```
https://dl-cdn.alpinelinux.org/alpine/latest-stable/community
```

### 2. Instalar

```sh
apk update
apk add docker docker-cli docker-compose
```

### 3. Configurar IPv6 no Docker

```sh
mkdir -p /etc/docker
nano /etc/docker/daemon.json
```

```json
{
  "ipv6": true,
  "fixed-cidr-v6": "fd00::/80"
}
```

### 4. Habilitar e iniciar

```sh
rc-update add docker boot
rc-service docker start
```

### 5. Verificar

```sh
docker version
docker run hello-world
```

### 6. Permitir uso sem root (opcional)

```sh
addgroup <seu-usuario> docker
```

> Faça logout e login novamente para o grupo ser aplicado.

---

## Referências

- [Alpine Linux ARM](https://dl-cdn.alpinelinux.org/alpine/latest-stable/releases/armhf/)
- [Armbian para Orange Pi PC](https://www.armbian.com/orange-pi-pc/)
- [Documentação Alpine Linux](https://wiki.alpinelinux.org/)
- [Docker no Alpine](https://wiki.alpinelinux.org/wiki/Docker)
