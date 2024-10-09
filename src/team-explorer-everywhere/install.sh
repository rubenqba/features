#!/bin/bash
set -ex

# Tiempo de actualización máxima (en segundos) para considerar válida la actualización
MAX_CACHE_AGE=$((60 * 60))  # 1 hora
UPDATE_FLAG="/var/run/apt-updated"

# Función para comprobar si necesitamos ejecutar 'apt-get update'
apt_get_update_if_needed() {
  if [ ! -f "$UPDATE_FLAG" ]; then
    local last_update_time="$(stat -c %Y /var/lib/apt/lists 2>/dev/null || echo 0)"
    local current_time="$(date +%s)"
    local age=$((current_time - last_update_time))

    if [ "$age" -gt "$MAX_CACHE_AGE" ]; then
      echo "El listado de paquetes es antiguo ($age segundos), ejecutando apt-get update..."
      apt-get update
      touch "$UPDATE_FLAG"  # Marcar que ya se ha actualizado
    else
      echo "El listado de paquetes ya está actualizado. No se ejecutará apt-get update."
    fi
  else
    echo "'apt-get update' ya se ejecutó en este script."
  fi
}

install_deps() {
  apt_get_update_if_needed;
  apt-get install curl unzip jq -yq
}

install_java() {
  apt_get_update_if_needed;
  apt-get install openjdk-17-jre -yq
}

# Función para agregar al PATH de diferentes shells
add_to_shell_profile() {
  local shell_profile="$1"
  local app_path="$2"
  local export_statement="export PATH=$app_path:\$PATH"

  if [ -f "$shell_profile" ]; then
    # Si el archivo de perfil existe y no tiene ya el comando, lo añadimos
    if ! grep -q "$export_statement" "$shell_profile"; then
      echo "$export_statement" >> "$shell_profile"
      echo "Agregado a $shell_profile"
    fi
  # else
  #   # Si el archivo de perfil no existe, lo creamos con el comando
  #   echo "$export_statement" > "$shell_profile"
  #   echo "Creado $shell_profile con la configuración de PATH"
  fi
}

install_tee() {
  BASE_DIR=$1
  version=$2

  if [ ! -d "$BASE_DIR/$version" ]; then
    echo "Installing TEE CLC version $version..."
    mkdir -p "$BASE_DIR"
    curl -vLo "$BASE_DIR/tee-clc.zip" https://github.com/microsoft/team-explorer-everywhere/releases/latest/download/TEE-CLC-${version}.zip
    unzip "$BASE_DIR/tee-clc.zip" -d "$BASE_DIR"
    rm -f "$BASE_DIR/tee-clc.zip"
    ln -sf "$BASE_DIR/TEE-CLC-$version" "$BASE_DIR/current"

    # Agregar el comando 'tf' a PATH
    add_to_shell_profile "/etc/bash.bashrc" "$BASE_DIR/current" # para Bash globalmente
    add_to_shell_profile "/etc/profile" "$BASE_DIR/current"     # para shells POSIX como sh
    # Agregar al PATH en zsh
    add_to_shell_profile "/etc/zsh/zshrc" "$BASE_DIR/current"   # para Zsh globalmente 
  else
    echo "Team Explorer Everywhere v$version is already installed"
  fi;
}

detect_latest_version() {
  VERSION=$(curl -sL https://api.github.com/repos/microsoft/team-explorer-everywhere/releases/latest | jq -r .name)
}

check_version() {
  version=$1
  result=$(curl -sL  "https://api.github.com/repos/microsoft/team-explorer-everywhere/releases/tags/$version" | jq -r .name)
  echo "check result: $result"

  [ "$result" == "null" ] && (echo "Team Explorer Everywhere v$version doesn't exists"; exit 1)
  return 0;
}

echo "Activating feature 'team-explorer-everywhere'"

which curl 2>&1 > /dev/null || install_deps
which unzip 2>&1 > /dev/null || install_deps
which jq 2>&1 > /dev/null || install_deps
which java 2>&1 > /dev/null || install_java

VERSION=${VERSION:-latest}

[ "$VERSION" == "latest" ] && detect_latest_version;
echo "The provided version is: $VERSION"

check_version "$VERSION";
echo "The verified version is: $VERSION"

INSTALL_DIR="/opt/team-explorer-everywhere"

# The 'install.sh' entrypoint script is always executed as the root user.
#
# These following environment variables are passed in by the dev container CLI.
# These may be useful in instances where the context of the final 
# remoteUser or containerUser is useful.
# For more details, see https://containers.dev/implementors/features#user-env-var
echo "The effective dev container remoteUser is '$_REMOTE_USER'"
echo "The effective dev container remoteUser's home directory is '$_REMOTE_USER_HOME'"

echo "The effective dev container containerUser is '$_CONTAINER_USER'"
echo "The effective dev container containerUser's home directory is '$_CONTAINER_USER_HOME'"

install_tee "$INSTALL_DIR" "$VERSION" 
