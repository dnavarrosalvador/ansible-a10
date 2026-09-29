# A10 vThunder · SLB Telnet / HTTP / SSH / HTTPS hacia 2× Cisco 7200 (variante CLI)

Misma funcionalidad que la variante aXAPI, pero configurando el A10 **por CLI
(SSH)** con la colección `a10.acos_cli` (conexión `network_cli`, módulos
`acos_config` / `acos_command`). Los comandos ACOS se generan desde el mismo
modelo de datos (`group_vars/vthunder.yml`) mediante plantillas Jinja2.

## Estructura

```
a10_slb_cli/
├── ansible.cfg               # config (inventario, colecciones, timeouts de conexión)
├── requirements.yml          # a10.acos_cli + ansible.netcommon
├── site_cli.yml              # orquestador: interfaz -> balanceo (punto de entrada)
├── a10_interface_cli.yml     # 1) interfaz de datos (172.22.2.0/24)
├── a10_slb_cisco7200_cli.yml  # 2) balanceo SLB (Telnet/HTTP/SSH/HTTPS)
├── inventory.ini
├── group_vars/
│   ├── vthunder.yml          # conexión network_cli + modelo de datos
│   └── vault.yml             # credenciales cifradas con Ansible Vault
├── templates/
│   ├── interface_cli.j2      # CLI ACOS de la interfaz
│   └── slb_cli.j2            # CLI ACOS del balanceo
├── .gitignore
└── README.md
```

## Diferencias clave frente a la variante aXAPI

| | aXAPI (`a10.acos_axapi`) | CLI (`a10.acos_cli`) |
|---|---|---|
| Conexión | `local` → HTTPS a `/axapi/v3` (puerto 443) | `network_cli` → SSH (puerto 22) |
| Requisito en el equipo | aXAPI habilitada | **SSH de gestión habilitado** |
| Config | módulos por recurso | comandos ACOS (`acos_config`) |
| Guardar | `a10_write_memory` (dio problemas) | `write memory` vía `acos_command` |
| Privilegio | usuario R/W AXAPI | usuario R/W + **enable** (become) |

## Requisitos

```bash
ansible-galaxy collection install -r requirements.yml -p ./collections
```

En el vThunder debe estar habilitado el acceso **SSH de gestión** y la cuenta
debe tener privilegio de escritura y acceso a modo enable.

## Uso

```bash
# 1. Ajusta la IP del vThunder en inventory.ini
# 2. Ajusta interfaz/servidores/servicios/VIP en group_vars/vthunder.yml
# 3. Define y cifra la contraseña:
ansible-vault encrypt group_vars/vault.yml

# 4. Ejecuta todo en orden (interfaz -> balanceo):
ansible-playbook site_cli.yml --ask-vault-pass

# Por separado:
ansible-playbook a10_interface_cli.yml --ask-vault-pass
ansible-playbook a10_slb_cisco7200_cli.yml --ask-vault-pass

# Con verificación (show slb virtual-server al final):
ansible-playbook site_cli.yml --ask-vault-pass -e verify_config=true
```

## Configuración ACOS que se genera

```text
! Interfaz (a10_interface_cli.yml)
interface ethernet 1
 enable
 ip address 172.22.2.1 255.255.255.0

! Balanceo (a10_slb_cisco7200_cli.yml)
slb server cisco7200-1 172.22.2.11
 port 23 tcp
 port 80 tcp
 port 22 tcp
 port 443 tcp
slb server cisco7200-2 172.22.2.12
 port 23 tcp
 port 80 tcp
 port 22 tcp
 port 443 tcp
slb service-group sg-telnet tcp
 method round-robin
 member cisco7200-1 23
 member cisco7200-2 23
slb service-group sg-http tcp
 method round-robin
 member cisco7200-1 80
 member cisco7200-2 80
slb service-group sg-ssh tcp
 method round-robin
 member cisco7200-1 22
 member cisco7200-2 22
slb service-group sg-https tcp
 method round-robin
 member cisco7200-1 443
 member cisco7200-2 443
slb virtual-server vip-cisco7200 10.10.10.100
 port 23 tcp
  service-group sg-telnet
 port 80 http
  service-group sg-http
 port 22 tcp
  service-group sg-ssh
 port 443 tcp
  service-group sg-https
```

## Notas

- **`ansible_network_os`.** Se usa el FQCN `a10.acos_cli.acos`. Si tu versión de
  ansible-core no descubre los plugins cliconf/terminal, usa `acos` y descomenta
  las líneas `cliconf_plugins` / `terminal_plugins` en `ansible.cfg`.
- **Enable / become.** Se entra en modo privilegiado con `become: enable`. Si tu
  equipo no tiene enable password, deja `ansible_become_password: ""`.
- **Orden de comandos.** La plantilla emite los comandos de forma que ACOS
  mantiene el contexto de submodo (server → port, service-group → member,
  virtual-server → port → service-group). No hace falta `exit` entre bloques.
- **Idempotencia.** `acos_config` reaplica los comandos; ACOS ignora los que ya
  existen, así que reejecutar es seguro (aunque marcará `changed`).
