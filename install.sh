#!/usr/bin/env bash
# Instala la skill web-dev-loop y los agentes nativos en la configuracion global de OpenCode.
#
#   git clone https://github.com/bialyLT/web-dev-loop.git
#   cd web-dev-loop
#   chmod +x install.sh && ./install.sh
#
# La skill queda disponible en todos los proyectos. Un proyecto puede pisarla con
# .opencode/skills/web-dev-loop/.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"
SKILL_SRC="$REPO_DIR/skills/web-dev-loop"
AGENTS_SRC="$REPO_DIR/agents"

if [ ! -d "$SKILL_SRC" ]; then
  echo "No encuentro skills/web-dev-loop en $REPO_DIR" >&2
  exit 1
fi
if [ ! -d "$AGENTS_SRC" ]; then
  echo "No encuentro agents/ en $REPO_DIR" >&2
  exit 1
fi

echo "Repo:   $REPO_DIR"
echo "Config: $CONFIG_DIR"
echo

mkdir -p "$CONFIG_DIR/skills" "$CONFIG_DIR/agents"
rm -rf "$CONFIG_DIR/skills/web-dev-loop"
cp -R "$SKILL_SRC" "$CONFIG_DIR/skills/web-dev-loop"
echo "Skill instalada: $CONFIG_DIR/skills/web-dev-loop"

cp "$AGENTS_SRC"/*.md "$CONFIG_DIR/agents/"
echo "Agentes instalados: $CONFIG_DIR/agents"
ls -1 "$CONFIG_DIR/agents"

echo
echo "Listo."
echo "La skill se anuncia sola cuando el pedido encaja (roadmap, propuesta, fase, testers)."
echo "Para usarla de forma explicita: @web-dev-loop"
echo
echo "Opcional: pegar el bloque de MCPs (context7 / memoria) en tu opencode.json."
echo "No instales el MCP de Maestro si usas el CLI de Maestro: pelean el lock de sesion."
