# A10 vThunder · SLB Telnet / HTTP / SSH hacia 2× Cisco 7200

Playbook Ansible que configura, **vía la aXAPI v3 de ACOS** (colección
`a10.acos_axapi`), un balanceo de carga en un A10 vThunder hacia dos routers
Cisco 7200, exponiendo acceso balanceado a **Telnet (23)**, **HTTP (80)** y
**SSH (22)** a través de un único VIP.

## Estructura

```
a10_slb_cisco7200/
├── a10_slb_cisco7200.yml      # playbook principal
├── inventory.ini             # apunta al vThunder
├── group_vars/
│   └── vthunder.yml          # conexión aXAPI + modelo de datos (servidores, servicios, VIP)
└── README.md
```

## Requisitos

```bash
# Colección A10 + dependencia jmespath (para el filtro json_query)
ansible-galaxy collection install a10.acos_axapi
pip install jmespath
```

La aXAPI debe estar habilitada en el vThunder y accesible por HTTPS en el
puerto configurado (`ansible_port`, por defecto 443).

## Uso

```bash
# 1. Ajusta IP del vThunder en inventory.ini
# 2. Ajusta servidores/servicios/VIP/credenciales en group_vars/vthunder.yml
# 3. Ejecuta:
ansible-playbook -i inventory.ini a10_slb_cisco7200.yml

# Con verificación del VIP al final:
ansible-playbook -i inventory.ini a10_slb_cisco7200.yml -e verify_config=true
```

### Credenciales con Ansible Vault (recomendado)

```bash
ansible-vault create group_vars/vault.yml
# dentro: vault_a10_password: "tu_password"
ansible-playbook -i inventory.ini a10_slb_cisco7200.yml --ask-vault-pass
```

## Qué configura (equivalente CLI ACOS)

```text
slb server cisco7200-1 10.10.10.11
   port 23 tcp
   port 80 tcp
   port 22 tcp
   port 443 tcp
slb server cisco7200-2 10.10.10.12
   port 23 tcp
   port 80 tcp
   port 22 tcp
   port 443 tcp

slb service-group sg-telnet tcp   -> miembros :23 de ambos servidores
slb service-group sg-http   tcp   -> miembros :80 de ambos servidores
slb service-group sg-ssh    tcp   -> miembros :22 de ambos servidores
slb service-group sg-https  tcp   -> miembros :443 de ambos servidores

slb virtual-server vip-cisco7200 10.10.10.100
   port 23 tcp   service-group sg-telnet
   port 80 http  service-group sg-http
   port 22 tcp   service-group sg-ssh
   port 443 tcp  service-group sg-https
```

## Notas

- **Health checks:** ACOS aplica un health-check TCP por defecto a cada puerto
  real, suficiente para telnet/ssh y para una comprobación L4 de HTTP. Si quieres
  un monitor HTTP L7 (GET / esperando 200) o un monitor personalizado, se añade
  con `a10.acos_axapi.a10_health_monitor` y se referencia en el puerto del
  servidor o en el service-group.
- **HTTP L4 vs L7:** el puerto virtual de HTTP usa tipo `http` (L7), lo que
  permite añadir plantillas de persistencia/HTTP. Si prefieres balanceo L4 puro
  también para HTTP, cambia `vport_protocol: http` por `tcp` en `services`.
- **Idempotencia:** los módulos son idempotentes; reejecutar el playbook
  reconcilia el estado sin duplicar objetos.
- **AAP:** para ejecutarlo en AAP 2.5, incluye `a10.acos_axapi` y `jmespath` en
  el Execution Environment (ansible-builder) y parametriza credenciales vía
  Credential Type custom o Vault.
