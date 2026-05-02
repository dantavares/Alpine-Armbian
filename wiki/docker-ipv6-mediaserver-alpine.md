# Docker + IPv6 + Media Server no Alpine Linux — Orange Pi PC

## Problema

O container `qbittorrent-nox` subia junto com o Docker no boot, mas não reconhecia rede IPv4 nem IPv6 externa. Ao reiniciar o container manualmente, tudo funcionava normalmente.

**Causa raiz:** O container subia antes da rede Docker estar completamente configurada, especialmente o IPv6 que depende do SLAAC e do roteamento estar estável.

---

## Solução

Combinação de duas abordagens:

1. `restart: no` no `qbittorrent-nox` — impede o Docker de subir o container automaticamente no boot
2. Tarefa no `cron` com delay — sobe o container após o sistema estar estável

---

## 1. Configuração do Docker para IPv6

### /etc/docker/daemon.json

```json
{
  "ipv6": true,
  "fixed-cidr-v6": "fd00::/80"
}
```

### Reiniciar o Docker após alterar

```sh
rc-service docker restart
```

---

## 2. Compose File

```yaml
name: media-server
services:
    plex:
        build: plex/
        container_name: plex
        restart: unless-stopped
        network_mode: host
        volumes:
           - ${STG_PATH}:/media
           - ${CONF_PATH}:/root/Library
           - /mnt/sda1/Temp:/tmp

    qbtnox:
        image: qbittorrentofficial/qbittorrent-nox
        container_name: qbittorrent-nox
        restart: no
        networks:
            - mserver
        ports:
            - "127.0.0.1:8083:8083"
            - "6881:6881"
        volumes:
            - ${CONF_PATH}/qbt-nox:/config
            - ${STG_PATH}:/downloads
        depends_on:
            jackett:
                condition: service_healthy
        environment:
            QBT_LEGAL_NOTICE: "confirm"
            QBT_WEBUI_PORT: "8083"
            QBT_TORRENTING_PORT: "6881"
            TZ: America/Sao_Paulo

    jackett:
        image: 44934045/jackett
        container_name: jackett
        restart: unless-stopped
        networks:
           - mserver
        environment:
            PUID: 1000
            PGID: 1000
            TZ: "America/Sao_Paulo"
            AUTO_UPDATE: true
        volumes:
           - ${CONF_PATH}/jackett:/config
           - /mnt/sda1/Temp:/downloads
        healthcheck:
            test: ["CMD", "ping6", "-c", "1", "2001:4860:4860::8888"]
            interval: 15s
            timeout: 10s
            retries: 10
            start_period: 60s

networks:
    mserver:
        enable_ipv6: true
        ipam:
            config:
                - subnet: "172.21.0.0/16"
                - subnet: "fd00:cafe::/64"
```

---

## 3. Cron para subir o container no boot

```sh
crontab -e
```

Adicione:

```sh
@reboot sleep 120 && docker start qbittorrent-nox
```

O `sleep 120` aguarda 2 minutos para garantir que a rede IPv6 esteja completamente estável antes de subir o container.

Verifique se foi adicionado:

```sh
crontab -l
```

---

## 4. Subir o compose

```sh
docker compose --env-file config.env -f mediaserver-compose.yml up -d --force-recreate
```

---

## Observações

| Ponto | Detalhe |
|---|---|
| `restart: no` | Necessário no `qbtnox` para evitar subida prematura no boot |
| `restart: unless-stopped` | Usado nos demais containers normalmente |
| `sleep 120` | Ajuste conforme necessário dependendo do tempo de boot |
| `healthcheck` no jackett | Garante que o IPv6 está funcional antes do `qbtnox` subir via `depends_on` |
| `fd00:cafe::/64` | Subnet IPv6 ULA da rede interna do Docker |
| `172.21.0.0/16` | Subnet IPv4 livre — verificar conflito com `docker network ls` |

---

## Redes Docker em uso (referência)

| Subnet IPv4 | Subnet IPv6 |
|---|---|
| 172.17.0.0/16 | fd00::/80 |
| 172.18.0.0/16 | — |
| 172.19.0.0/16 | fd2d:497f:a2e0::/64 |
| 172.20.0.0/16 | — |
| 172.22.0.0/16 | — |
| **172.21.0.0/16** | **fd00:cafe::/64** ← usadas pelo media-server |
