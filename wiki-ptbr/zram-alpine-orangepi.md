# ZRAM no Alpine Linux — Orange Pi PC

## Pré-requisitos

- Alpine Linux instalado no Orange Pi PC (SoC Allwinner H3)
- Acesso root

---

## 1. Instalar o pacote

```sh
apk add zram-init
```

---

## 2. Carregar o módulo do kernel

```sh
modprobe zram
```

Habilitar no boot:

```sh
echo "zram" >> /etc/modules
```

> Para verificar se o módulo está disponível no seu kernel:
> ```sh
> find /lib/modules/$(uname -r) -name "zram*"
> ```

---

## 3. Verificar algoritmos disponíveis

```sh
cat /sys/block/zram0/comp_algorithm
```

Exemplo de saída:
```
[lzo-rle] lzo lz4 zstd
```

O algoritmo entre colchetes é o padrão do kernel.

---

## 4. Configurar

```sh
nano /etc/conf.d/zram-init
```

```sh
num_devices="1"
type0="swap"
size0="512"       # em MB, sem sufixo M
algo0="lzo-rle"   # algoritmo padrão do kernel
flag0="100"       # prioridade do swap (só o número, sem -p)
```

---

## 5. Iniciar e habilitar no boot

```sh
rc-service zram-init start
rc-update add zram-init boot
```

---

## 6. Verificar

```sh
swapon -s
zramctl
```

Saída esperada do `swapon -s`:
```
Filename        Type        Size      Used    Priority
/dev/zram0      partition   524284    0       100
```

---

## Observações importantes

| Ponto | Detalhe |
|---|---|
| `size0` | Somente número em MB, sem sufixo `M` — ex: `512` |
| `flag0` | Somente o número da prioridade, sem `-p` — ex: `100` |
| Módulo | O `zram` precisa estar carregado antes do serviço iniciar |
| Algoritmo | Verifique o disponível no seu kernel antes de configurar |

---

## Problemas comuns

| Erro | Causa | Solução |
|---|---|---|
| `can't open '/sys/block/zram0/comp_algorithm'` | Módulo não carregado | `modprobe zram` |
| `sh: 512M: bad number` | Sufixo `M` no tamanho | Usar só o número: `size0="512"` |
| `swapon: failed to parse priority: '-p 100'` | Formato errado do flag | Usar só o número: `flag0="100"` |
| `swapon -s` retorna vazio | Serviço não iniciou corretamente | Verificar `/etc/conf.d/zram-init` |
