# IPv6 no Alpine Linux — Orange Pi PC

## Problema

O Alpine Linux não obtinha rota default IPv6 via SLAAC, mesmo com endereço público atribuído na interface. O `ping6` retornava `Network unreachable`.

A causa raiz é que quando `net.ipv6.conf.eth0.forwarding=1` está ativo (habilitado pelo Docker), o kernel ignora os Router Advertisements (RA) do roteador com `accept_ra=1`. Isso faz a rota default expirar imediatamente (`expires 0sec`).

---

## Solução

### 1. Habilitar IPv6 na interface de rede

Edite o arquivo de interfaces:

```sh
nano /etc/network/interfaces
```

Adicione `iface eth0 inet6 auto` para habilitar SLAAC:

```sh
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
iface eth0 inet6 auto
```

---

### 2. Corrigir o accept_ra para funcionar com forwarding

Com `forwarding=1`, o valor `accept_ra=1` é ignorado. É necessário usar `accept_ra=2`:

```sh
nano /etc/sysctl.conf
```

Adicione:

```
net.ipv6.conf.eth0.accept_ra=2
```

Aplique sem reiniciar:

```sh
sysctl -p
```

---

### 3. Reiniciar a interface e verificar

```sh
rc-service networking restart
ip -6 route show default
ping6 -c 3 google.com
```

Saída esperada do `ip -6 route show default`:
```
default via fe80::xxxx:xxxx:xxxx:xxxx dev eth0  metric 1024
```

---

### 4. Habilitar IPv6 no Docker

Crie o arquivo de configuração do Docker caso não exista:

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

Reinicie o Docker:

```sh
rc-service docker restart
```

---

## Resumo das causas e soluções

| Problema | Causa | Solução |
|---|---|---|
| `Network unreachable` no ping6 | Sem rota default IPv6 | Adicionar `inet6 auto` no `/etc/network/interfaces` |
| Rota com `expires 0sec` | `forwarding=1` ignora RA com `accept_ra=1` | Definir `accept_ra=2` no `sysctl.conf` |
| Container Docker sem IPv6 público | Docker sem IPv6 habilitado | Configurar `daemon.json` com `ipv6: true` |

---

## Observações

- O Docker habilita `forwarding=1` automaticamente, por isso o `accept_ra=2` é necessário em qualquer Alpine que rode Docker e use IPv6
- O `accept_ra=2` faz o kernel aceitar RAs mesmo com forwarding ativo
- A configuração persiste nos próximos boots via `/etc/sysctl.conf`
