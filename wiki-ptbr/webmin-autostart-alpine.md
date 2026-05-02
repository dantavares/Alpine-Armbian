# Webmin no Alpine Linux — Correção do Autostart

## Problema

O Webmin inicia manualmente com `rc-service webmin start`, mas não inicializa automaticamente no boot mesmo após `rc-update add webmin default`.

A causa é que o script `/etc/init.d/webmin` instalado pelo Webmin é **SysV style**, incompatível com o **OpenRC** do Alpine Linux. O OpenRC não consegue gerenciar o ciclo de vida do serviço corretamente com esse formato.

---

## Solução

Criar um script OpenRC wrapper que chama os scripts nativos do Webmin.

### 1. Criar o script OpenRC

```sh
nano /etc/init.d/webmin-openrc
```

Cole o conteúdo:

```sh
#!/sbin/openrc-run

description="Webmin web-based administration interface"

depend() {
    need net
    after sshd
}

start() {
    ebegin "Starting Webmin"
    /etc/webmin/.start-init
    eend $?
}

stop() {
    ebegin "Stopping Webmin"
    /etc/webmin/.stop-init
    eend $?
}
```

### 2. Tornar executável

```sh
chmod +x /etc/init.d/webmin-openrc
```

### 3. Remover o script antigo do boot

```sh
rc-update del webmin
rc-update del webmin boot
```

### 4. Adicionar o novo script ao boot

```sh
rc-update add webmin-openrc default
```

### 5. Testar

```sh
rc-service webmin-openrc start
rc-status default | grep webmin
```

Saída esperada:
```
 webmin-openrc                                                                  [  started  ]
```

---

## Observações

| Ponto | Detalhe |
|---|---|
| Script original | `/etc/init.d/webmin` — SysV, não compatível com OpenRC |
| Script novo | `/etc/init.d/webmin-openrc` — OpenRC nativo |
| Dependência | `need net` garante que a rede sobe antes do Webmin |
| Scripts do Webmin | `.start-init` e `.stop-init` em `/etc/webmin/` são preservados |

> **Atenção:** Ao atualizar o Webmin, o script `/etc/init.d/webmin` pode ser sobrescrito, mas o `/etc/init.d/webmin-openrc` não será afetado pois é independente.
