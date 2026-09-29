#!/usr/bin/env bash
# ============================================================================
#  setup_a10_slb_cli.sh
#
#  Crea la estructura de carpetas del proyecto CLI y coloca cada fichero
#  (que normalmente se descarga "suelto") en su carpeta correspondiente.
#
#  Uso:
#     ./setup_a10_slb_cli.sh [DIR_ORIGEN] [DIR_DESTINO]
#
#     DIR_ORIGEN   carpeta donde están los ficheros sueltos   (por defecto: .)
#     DIR_DESTINO  carpeta raíz del proyecto a construir       (por defecto: a10_slb_cli)
#
#  Ejemplos:
#     ./setup_a10_slb_cli.sh                       # ficheros en el dir actual
#     ./setup_a10_slb_cli.sh ~/Descargas           # ficheros en ~/Descargas
#     ./setup_a10_slb_cli.sh ~/Descargas ./miproy  # destino personalizado
# ============================================================================

set -euo pipefail

SRC="${1:-.}"
DEST="${2:-a10_slb_cli}"

# --- Mapa de ficheros -> subcarpeta destino ("" = raíz del proyecto) --------
ROOT_FILES=(
  ansible.cfg
  requirements.yml
  inventory.ini
  site_cli.yml
  a10_interface_cli.yml
  a10_slb_cisco7200_cli.yml
  .gitignore
  README.md
)
GROUPVARS_FILES=( vthunder.yml vault.yml )
TEMPLATE_FILES=( interface_cli.j2 slb_cli.j2 )

echo ">> Creando estructura en '$DEST/'..."
mkdir -p "$DEST/group_vars" "$DEST/templates"

move_file() {
  local name="$1" subdir="$2"
  local src="$SRC/$name"
  local dst="$DEST/${subdir}${name}"

  # Ya está en su sitio (mismo fichero): no hacer nada
  if [[ -f "$src" && -f "$dst" && "$src" -ef "$dst" ]]; then
    echo "  [==]  ${subdir}${name} (ya está en su sitio)"
    return
  fi

  if [[ -f "$src" ]]; then
    mkdir -p "$(dirname "$dst")"
    mv -f "$src" "$dst"
    echo "  [OK]  $name  ->  ${subdir}${name}"
  elif [[ -f "$dst" ]]; then
    echo "  [==]  ${subdir}${name} (ya está en su sitio)"
  else
    echo "  [!!]  $name  no encontrado en '$SRC' (omitido)"
  fi
}

echo ">> Colocando ficheros..."
for f in "${ROOT_FILES[@]}";      do move_file "$f" "";            done
for f in "${GROUPVARS_FILES[@]}"; do move_file "$f" "group_vars/"; done
for f in "${TEMPLATE_FILES[@]}";  do move_file "$f" "templates/";  done

echo ">> Estructura final:"
if command -v tree >/dev/null 2>&1; then
  tree -a --noreport "$DEST"
else
  ( cd "$DEST" && find . -not -path '*/.git/*' | sort )
fi

cat <<EOF

>> Hecho. Siguientes pasos:
   cd "$DEST"
   ansible-galaxy collection install -r requirements.yml -p ./collections
   ansible-vault encrypt group_vars/vault.yml        # tras poner la password real
   ansible-playbook site_cli.yml --ask-vault-pass
EOF
